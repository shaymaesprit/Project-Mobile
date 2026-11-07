import logging
from datetime import datetime, timezone
from uuid import UUID

from sqlalchemy import delete, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.core.exceptions import ResourceNotFoundError, StudyMateError
from app.models.extended import Notification, NotificationDevice
from app.services import firebase_service

logger = logging.getLogger("studymate.devices")


class DeviceConflictError(StudyMateError):
    status_code = 409
    code = "device_token_conflict"


class DeviceService:
    def __init__(self, db: Session) -> None:
        self._db = db

    def register(
        self, uid: str, fcm_token: str, platform: str, device_name: str | None
    ) -> NotificationDevice:
        device = self._db.scalar(
            select(NotificationDevice).where(
                NotificationDevice.owner_uid == uid,
                NotificationDevice.fcm_token == fcm_token,
            )
        )
        now = datetime.now(timezone.utc)
        try:
            if device is None:
                device = NotificationDevice(
                    owner_uid=uid, fcm_token=fcm_token, platform=platform,
                    device_name=device_name, last_seen_at=now,
                )
                self._db.add(device)
            else:
                device.platform = platform
                device.device_name = device_name
                device.last_seen_at = now
            self._db.commit()
        except IntegrityError as error:
            self._db.rollback()
            raise DeviceConflictError(
                "Ce jeton est déjà enregistré par un autre compte. "
                "Déconnecte l’autre compte sur cet appareil."
            ) from error
        self._db.refresh(device)
        return device

    def unregister(self, uid: str, device_id: UUID) -> None:
        device = self._db.scalar(
            select(NotificationDevice).where(
                NotificationDevice.id == device_id,
                NotificationDevice.owner_uid == uid,
            )
        )
        if device is None:
            raise ResourceNotFoundError("Device not found.")
        self._db.delete(device)
        self._db.commit()

    def tokens(self, uid: str) -> list[str]:
        return list(self._db.scalars(
            select(NotificationDevice.fcm_token).where(NotificationDevice.owner_uid == uid)
        ))

    def remove_tokens(self, uid: str, tokens: list[str]) -> None:
        if not tokens:
            return
        self._db.execute(delete(NotificationDevice).where(
            NotificationDevice.owner_uid == uid,
            NotificationDevice.fcm_token.in_(tokens),
        ))
        self._db.commit()


class NotificationDispatcher:
    """Stores a notification, mirrors it to Firestore and pushes it through FCM."""

    def __init__(self, db: Session) -> None:
        self._db = db
        self._devices = DeviceService(db)

    def dispatch(
        self, uid: str, notification_type: str, title: str, body: str,
        payload: dict | None = None,
    ) -> Notification:
        notification = Notification(
            owner_uid=uid, notification_type=notification_type, title=title,
            body=body, payload=payload or {},
        )
        self._db.add(notification)
        self._db.commit()
        self._db.refresh(notification)

        invalid = firebase_service.send_push(
            self._devices.tokens(uid), title, body,
            {"notification_id": str(notification.id), "type": notification_type},
        )
        self._devices.remove_tokens(uid, invalid)
        notification.sent_at = datetime.now(timezone.utc)
        self._db.commit()
        self._db.refresh(notification)

        firebase_service.sync_notification(uid, str(notification.id), {
            "type": notification_type, "title": title, "body": body,
            "payload": notification.payload, "created_at": notification.created_at,
            "sent_at": notification.sent_at, "read_at": None,
        })
        return notification
