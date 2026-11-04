from uuid import UUID

from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.models.extended import Notification


class NotificationRepository:
    def __init__(self, db: Session) -> None:
        self._db = db

    def list_for_owner(
        self, owner_uid: str, *, limit: int, offset: int
    ) -> list[Notification]:
        return list(
            self._db.scalars(
                select(Notification)
                .where(Notification.owner_uid == owner_uid)
                .order_by(Notification.created_at.desc())
                .limit(limit)
                .offset(offset)
            )
        )

    def get_for_owner(
        self, notification_id: UUID, owner_uid: str
    ) -> Notification | None:
        return self._db.scalar(
            select(Notification).where(
                Notification.id == notification_id,
                Notification.owner_uid == owner_uid,
            )
        )

    def mark_read(self, notification: Notification) -> Notification:
        if notification.read_at is None:
            notification.read_at = self._db.scalar(select(func.now()))
            self._db.commit()
            self._db.refresh(notification)
        return notification
