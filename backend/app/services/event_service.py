from datetime import datetime, timezone
from typing import Any
from uuid import UUID

from sqlalchemy.orm import Session

from app.core.exceptions import EventScheduleConflictError, InvalidResourceStateError
from app.repositories.owned_resource_repository import OwnedResourceRepository
from app.services.event_conflicts import (
    Conflict,
    describe_conflicts,
    find_conflicts,
    user_timezone,
)
from app.services.owned_resource_service import OwnedResourceService
from app.services.reminder_service import sync_event_reminders

_SCHEDULE_FIELDS = {"starts_at", "ends_at", "event_type"}


class EventService(OwnedResourceService):
    def __init__(self, repository: OwnedResourceRepository, db: Session) -> None:
        super().__init__(repository, "Event")
        self._db = db

    # ----- conflits -----------------------------------------------------
    def check_conflicts(
        self,
        owner_uid: str,
        *,
        event_type: str,
        starts_at: datetime,
        ends_at: datetime | None,
        exclude_event_id: UUID | None = None,
    ) -> list[Conflict]:
        self._validate_range(starts_at, ends_at)
        return find_conflicts(
            self._db,
            owner_uid,
            event_type=event_type,
            starts_at=starts_at,
            ends_at=ends_at,
            exclude_event_id=exclude_event_id,
        )

    def _raise_if_conflicting(
        self,
        owner_uid: str,
        *,
        event_type: str,
        starts_at: datetime,
        ends_at: datetime | None,
        exclude_event_id: UUID | None,
        force: bool,
    ) -> None:
        if force:
            return
        conflicts = self.check_conflicts(
            owner_uid,
            event_type=event_type,
            starts_at=starts_at,
            ends_at=ends_at,
            exclude_event_id=exclude_event_id,
        )
        if conflicts:
            raise EventScheduleConflictError(
                describe_conflicts(conflicts, user_timezone(self._db, owner_uid)),
                extra={"conflicts": [item.as_dict() for item in conflicts]},
            )

    # ----- CRUD ---------------------------------------------------------
    def create(
        self, owner_uid: str, values: dict[str, Any], *, force: bool = False
    ) -> Any:
        self._validate_range(values["starts_at"], values.get("ends_at"))
        if values.get("status", "planned") != "cancelled":
            self._raise_if_conflicting(
                owner_uid,
                event_type=values.get("event_type", "other"),
                starts_at=values["starts_at"],
                ends_at=values.get("ends_at"),
                exclude_event_id=None,
                force=force,
            )
        event = super().create(owner_uid, values)
        sync_event_reminders(self._db, event)
        self._db.commit()
        return event

    def update(
        self,
        resource_id: UUID,
        owner_uid: str,
        changes: dict[str, Any],
        *,
        force: bool = False,
    ) -> Any:
        current = self.get(resource_id, owner_uid)
        starts_at = changes.get("starts_at", current.starts_at)
        ends_at = changes.get("ends_at", current.ends_at)
        event_type = changes.get("event_type", current.event_type)
        status = changes.get("status", current.status)
        self._validate_range(starts_at, ends_at)
        reactivated = current.status == "cancelled" and status != "cancelled"
        if status != "cancelled" and (_SCHEDULE_FIELDS & changes.keys() or reactivated):
            self._raise_if_conflicting(
                owner_uid,
                event_type=event_type,
                starts_at=starts_at,
                ends_at=ends_at,
                exclude_event_id=current.id,
                force=force,
            )
        event = super().update(resource_id, owner_uid, changes)
        sync_event_reminders(self._db, event)
        self._db.commit()
        return event

    @staticmethod
    def _validate_range(starts_at: datetime, ends_at: datetime | None) -> None:
        normalized_starts = EventService._as_utc(starts_at)
        normalized_ends = (
            EventService._as_utc(ends_at) if ends_at is not None else None
        )
        if normalized_ends is not None and normalized_ends < normalized_starts:
            raise InvalidResourceStateError(
                "ends_at must be greater than or equal to starts_at."
            )

    @staticmethod
    def _as_utc(value: datetime) -> datetime:
        if value.tzinfo is None:
            return value.replace(tzinfo=timezone.utc)
        return value.astimezone(timezone.utc)
