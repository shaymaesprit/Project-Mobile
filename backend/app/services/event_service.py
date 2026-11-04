from datetime import datetime, timezone
from typing import Any
from uuid import UUID

from app.core.exceptions import InvalidResourceStateError
from app.repositories.owned_resource_repository import OwnedResourceRepository
from app.services.owned_resource_service import OwnedResourceService


class EventService(OwnedResourceService):
    def __init__(self, repository: OwnedResourceRepository) -> None:
        super().__init__(repository, "Event")

    def create(self, owner_uid: str, values: dict[str, Any]) -> Any:
        self._validate_range(values["starts_at"], values.get("ends_at"))
        return super().create(owner_uid, values)

    def update(
        self, resource_id: UUID, owner_uid: str, changes: dict[str, Any]
    ) -> Any:
        current = self.get(resource_id, owner_uid)
        starts_at = changes.get("starts_at", current.starts_at)
        ends_at = changes.get("ends_at", current.ends_at)
        self._validate_range(starts_at, ends_at)
        return super().update(resource_id, owner_uid, changes)

    @staticmethod
    def _validate_range(
        starts_at: datetime, ends_at: datetime | None
    ) -> None:
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
