from datetime import datetime, timezone
from uuid import UUID

from app.core.exceptions import ResourceNotFoundError
from app.models.extended import Notification
from app.repositories.notification_repository import NotificationRepository
from app.services import firebase_service


class NotificationService:
    def __init__(self, repository: NotificationRepository) -> None:
        self._repository = repository

    def list_notifications(
        self,
        owner_uid: str,
        *,
        limit: int,
        offset: int,
        unread_only: bool = False,
        notification_type: str | None = None,
    ) -> list[Notification]:
        return self._repository.list_for_owner(
            owner_uid,
            limit=limit,
            offset=offset,
            unread_only=unread_only,
            notification_type=notification_type,
        )

    def unread_count(self, owner_uid: str) -> int:
        return self._repository.unread_count(owner_uid)

    def mark_all_read(self, owner_uid: str) -> int:
        ids = self._repository.mark_all_read(owner_uid)
        for notification_id in ids[:200]:  # miroir Firestore au mieux
            firebase_service.sync_notification(
                owner_uid, notification_id, {"read_at": datetime.now(timezone.utc)}
            )
        return len(ids)

    def delete(self, notification_id: UUID, owner_uid: str) -> None:
        notification = self._repository.get_for_owner(notification_id, owner_uid)
        if notification is None:
            raise ResourceNotFoundError("Notification not found.")
        self._repository.delete(notification)
        firebase_service.delete_notification(owner_uid, str(notification_id))

    def mark_read(
        self, notification_id: UUID, owner_uid: str
    ) -> Notification:
        notification = self._repository.get_for_owner(notification_id, owner_uid)
        if notification is None:
            raise ResourceNotFoundError("Notification not found.")
        notification = self._repository.mark_read(notification)
        firebase_service.sync_notification(
            owner_uid, str(notification.id), {"read_at": notification.read_at}
        )
        return notification
