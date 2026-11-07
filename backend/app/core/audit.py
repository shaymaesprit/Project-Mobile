"""Audit trail for sensitive operations.

Logs a short hash of the UID (never the raw UID, e-mail or tokens)
under the ``studymate.audit`` logger so it can be routed to a separate sink.
"""

import hashlib
import logging

audit_logger = logging.getLogger("studymate.audit")


def _short_hash(uid: str | None) -> str:
    if not uid:
        return "anonymous"
    return hashlib.sha256(uid.encode("utf-8")).hexdigest()[:12]


def audit(event: str, uid: str | None, **details: str | int | bool) -> None:
    extra = " ".join(f"{key}={value}" for key, value in sorted(details.items()))
    audit_logger.info("event=%s user=%s %s", event, _short_hash(uid), extra)
