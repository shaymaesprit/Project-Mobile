"""Firestore / FCM / Storage helpers.

PostgreSQL remains the source of truth. Firestore only mirrors data that needs
real-time delivery (notifications, focus status) and is written exclusively by
this backend. Every call is best-effort: failures are logged and never raised
into the request that triggered them.
"""

import logging
from datetime import datetime
from typing import Any

from firebase_admin import firestore, messaging, storage

logger = logging.getLogger("studymate.firebase")

INVALID_TOKEN_ERRORS = (messaging.UnregisteredError, messaging.SenderIdMismatchError)


def _app():
    from app.api.deps import _firebase_app

    return _firebase_app()


def _user_doc(uid: str):
    return firestore.client(_app()).collection("users").document(uid)


def _jsonable(data: dict[str, Any]) -> dict[str, Any]:
    return {
        key: value.isoformat() if isinstance(value, datetime) else value
        for key, value in data.items()
    }


def sync_notification(uid: str, notification_id: str, data: dict[str, Any]) -> bool:
    try:
        _user_doc(uid).collection("notifications").document(notification_id).set(
            _jsonable(data), merge=True
        )
        return True
    except Exception as error:  # noqa: BLE001 - best effort
        logger.warning("Firestore notification sync failed (%s)", type(error).__name__)
        return False


def sync_realtime_status(uid: str, status: dict[str, Any]) -> bool:
    try:
        _user_doc(uid).collection("realtime_status").document("current").set(
            _jsonable(status), merge=True
        )
        return True
    except Exception as error:  # noqa: BLE001
        logger.warning("Firestore status sync failed (%s)", type(error).__name__)
        return False


def sync_focus_session(uid: str, session_id: str, data: dict[str, Any]) -> bool:
    try:
        _user_doc(uid).collection("focus_sessions").document(session_id).set(
            _jsonable(data), merge=True
        )
        return True
    except Exception as error:  # noqa: BLE001
        logger.warning("Firestore focus sync failed (%s)", type(error).__name__)
        return False


def send_push(
    tokens: list[str], title: str, body: str, data: dict[str, str] | None = None
) -> list[str]:
    """Sends a notification to the tokens; returns the tokens FCM reports as invalid."""
    if not tokens:
        return []
    try:
        message = messaging.MulticastMessage(
            tokens=tokens,
            notification=messaging.Notification(title=title, body=body),
            data={k: str(v) for k, v in (data or {}).items()},
        )
        response = messaging.send_each_for_multicast(message, app=_app())
    except Exception as error:  # noqa: BLE001
        logger.warning("FCM send failed (%s)", type(error).__name__)
        return []
    invalid = [
        token
        for token, result in zip(tokens, response.responses)
        if not result.success and isinstance(result.exception, INVALID_TOKEN_ERRORS)
    ]
    logger.info(
        "FCM sent: %d ok, %d failed, %d invalid",
        response.success_count, response.failure_count, len(invalid),
    )
    return invalid


def delete_user_cloud_data(uid: str) -> dict[str, bool]:
    """Deletes the user's Firestore documents and Storage objects."""
    result = {"firestore": False, "storage": False}
    try:
        firestore.client(_app()).recursive_delete(_user_doc(uid))
        result["firestore"] = True
    except Exception as error:  # noqa: BLE001
        logger.warning("Firestore cleanup failed (%s)", type(error).__name__)
    try:
        bucket = storage.bucket(app=_app())
        for blob in bucket.list_blobs(prefix=f"users/{uid}/"):
            blob.delete()
        result["storage"] = True
    except Exception as error:  # noqa: BLE001
        logger.warning("Storage cleanup failed (%s)", type(error).__name__)
    return result
