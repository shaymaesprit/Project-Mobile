"""In-memory sliding-window rate limiting (per client IP).

Suitable for a single process. Behind several workers or instances, replace the
store with Redis; the middleware interface stays the same.
"""

import threading
import time
from collections import defaultdict, deque

from starlette.requests import Request
from starlette.responses import JSONResponse
from starlette.types import ASGIApp, Receive, Scope, Send

WINDOW_SECONDS = 60.0
MAX_TRACKED_KEYS = 10_000
EXEMPT_PREFIXES = ("/api/v1/health", "/docs", "/redoc", "/openapi.json")


class RateLimiter:
    def __init__(self, general_limit: int, ai_limit: int) -> None:
        self.general_limit = general_limit
        self.ai_limit = ai_limit
        self._hits: dict[str, deque[float]] = defaultdict(deque)
        self._lock = threading.Lock()

    def reset(self) -> None:
        with self._lock:
            self._hits.clear()

    def check(self, client: str, bucket: str, limit: int) -> float | None:
        """Returns seconds to wait when over the limit, else records the hit."""
        if limit <= 0:
            return None
        now = time.monotonic()
        key = f"{bucket}:{client}"
        with self._lock:
            if len(self._hits) > MAX_TRACKED_KEYS:
                for stale in [k for k, v in self._hits.items() if not v or now - v[-1] > WINDOW_SECONDS]:
                    del self._hits[stale]
            hits = self._hits[key]
            while hits and now - hits[0] > WINDOW_SECONDS:
                hits.popleft()
            if len(hits) >= limit:
                return max(WINDOW_SECONDS - (now - hits[0]), 1.0)
            hits.append(now)
        return None


class RateLimitMiddleware:
    def __init__(self, app: ASGIApp, limiter: RateLimiter) -> None:
        self.app = app
        self.limiter = limiter

    async def __call__(self, scope: Scope, receive: Receive, send: Send) -> None:
        if scope["type"] != "http" or scope["method"] == "OPTIONS" or scope["path"].startswith(EXEMPT_PREFIXES):
            await self.app(scope, receive, send)
            return
        request = Request(scope)
        client = request.client.host if request.client else "unknown"
        is_ai = scope["path"].startswith("/api/v1/ai/")
        retry_after = None
        if is_ai:
            retry_after = self.limiter.check(client, "ai", self.limiter.ai_limit)
        if retry_after is None:
            retry_after = self.limiter.check(client, "all", self.limiter.general_limit)
        if retry_after is not None:
            response = JSONResponse(
                status_code=429,
                content={"detail": "Trop de requêtes. Réessaie dans un instant.",
                         "code": "rate_limited"},
                headers={"Retry-After": str(int(retry_after))},
            )
            await response(scope, receive, send)
            return
        await self.app(scope, receive, send)
