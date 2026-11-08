from uuid import UUID

from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.models.extended import Notification


class NotificationRepository:
    def __init__(self, db: Session) -> None:
        self._db = db

    def list_for_owner(
        self,
        owner_uid: str,
        *,
        limit: int,
        offset: int,
        unread_only: bool = False,
        notification_type: str | None = None,
    ) -> list[Notification]:
        statement = select(Notification).where(Notification.owner_uid == owner_uid)
        if unread_only:
            statement = statement.where(Notification.read_at.is_(None))
        if notification_type:
            statement = statement.where(
                Notification.notification_type == notification_type
            )
        return list(
            self._db.scalars(
                statement.order_by(Notification.created_at.desc())
                .limit(limit)
                .offset(offset)
            )
        )

    def unread_count(self, owner_uid: str) -> int:
        return int(
            self._db.scalar(
                select(func.count())
                .select_from(Notification)
                .where(
                    Notification.owner_uid == owner_uid,
                    Notification.read_at.is_(None),
                )
            )
            or 0
        )

    def mark_all_read(self, owner_uid: str) -> list[str]:
        """Marque tout comme lu ; renvoie les identifiants modifiés."""
        unread = list(
            self._db.scalars(
                select(Notification).where(
                    Notification.owner_uid == owner_uid,
                    Notification.read_at.is_(None),
                )
            )
        )
        if not unread:
            return []
        now = self._db.scalar(select(func.now()))
        for notification in unread:
            notification.read_at = now
        self._db.commit()
        return [str(notification.id) for notification in unread]

    def delete(self, notification: Notification) -> None:
        self._db.delete(notification)
        self._db.commit()

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
