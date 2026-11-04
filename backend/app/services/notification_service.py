from uuid import UUID

from app.core.exceptions import ResourceNotFoundError
from app.models.extended import Notification
from app.repositories.notification_repository import NotificationRepository


class NotificationService:
    def __init__(self, repository: NotificationRepository) -> None:
        self._repository = repository

    def list_notifications(
        self, owner_uid: str, *, limit: int, offset: int
    ) -> list[Notification]:
        return self._repository.list_for_owner(
            owner_uid, limit=limit, offset=offset
        )

    def mark_read(
        self, notification_id: UUID, owner_uid: str
    ) -> Notification:
        notification = self._repository.get_for_owner(notification_id, owner_uid)
        if notification is None:
            raise ResourceNotFoundError("Notification not found.")
        return self._repository.mark_read(notification)
