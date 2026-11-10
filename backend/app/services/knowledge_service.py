"""Enrichissement des notes avec Wikipédia (API REST Wikimedia, sans clé).

* Recherche : ``/w/rest.php/v1/search/page?q=...``
* Résumé :    ``/api/rest_v1/page/summary/{titre}``

Seul le terme recherché est envoyé à Wikipédia. Les résumés sont mis en
cache 6 h pour limiter les appels.
"""

from __future__ import annotations

import logging
import time as clock
from typing import Callable
from urllib.parse import quote

import httpx

from app.core.exceptions import StudyMateError

logger = logging.getLogger("studymate.knowledge")

SEARCH_URL = "https://{lang}.wikipedia.org/w/rest.php/v1/search/page"
SUMMARY_URL = "https://{lang}.wikipedia.org/api/rest_v1/page/summary/{title}"
USER_AGENT = "StudyMate/0.3 (https://github.com/shaymaesprit/Project-Mobile)"
CACHE_SECONDS = 6 * 3600


class KnowledgeUnavailableError(StudyMateError):
    status_code = 503
    code = "knowledge_unavailable"


Getter = Callable[[str, dict | None], dict]


def _http_get(url: str, params: dict | None) -> dict:
    response = httpx.get(
        url,
        params=params,
        timeout=8.0,
        headers={"User-Agent": USER_AGENT, "Accept": "application/json"},
        follow_redirects=True,
    )
    if response.status_code == 404:
        return {}
    response.raise_for_status()
    return response.json()


class KnowledgeService:
    _cache: dict[tuple[str, str], tuple[float, list[dict]]] = {}

    def __init__(self, getter: Getter | None = None) -> None:
        self._get = getter or _http_get

    def wikipedia(self, query: str, lang: str = "fr", limit: int = 3) -> list[dict]:
        query = " ".join(query.split())[:120]
        key = (lang, query.lower())
        cached = self._cache.get(key)
        if cached and clock.monotonic() - cached[0] < CACHE_SECONDS:
            return cached[1][:limit]
        try:
            search = self._get(SEARCH_URL.format(lang=lang), {"q": query, "limit": limit})
            results: list[dict] = []
            for page in (search.get("pages") or [])[:limit]:
                title = page.get("title")
                if not title:
                    continue
                summary = self._get(
                    SUMMARY_URL.format(lang=lang, title=quote(title.replace(" ", "_"), safe="")),
                    None,
                )
                extract = (summary.get("extract") or "").strip()
                if not extract or summary.get("type") == "disambiguation":
                    continue
                results.append({
                    "title": summary.get("title") or title,
                    "description": summary.get("description") or page.get("description"),
                    "extract": extract,
                    "url": ((summary.get("content_urls") or {}).get("desktop") or {}).get("page")
                    or f"https://{lang}.wikipedia.org/wiki/{quote(title.replace(' ', '_'))}",
                    "thumbnail": (summary.get("thumbnail") or {}).get("source"),
                })
        except (httpx.HTTPError, ValueError) as error:
            logger.warning("Wikipédia indisponible (%s)", error)
            raise KnowledgeUnavailableError(
                "Wikipédia est momentanément inaccessible. Réessaie plus tard."
            ) from error
        self._cache[key] = (clock.monotonic(), results)
        return results

    @classmethod
    def clear_cache(cls) -> None:
        cls._cache.clear()
