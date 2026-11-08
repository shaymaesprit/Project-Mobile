from datetime import datetime
from uuid import UUID

from fastapi import APIRouter, Depends, Query, Response, status

from app.api.deps import get_current_uid
from app.api.dependencies import get_event_service
from app.core.exceptions import InvalidResourceStateError
from app.models.extended import StudyEvent
from app.schemas.event import (
    ConflictCheckResponse,
    ConflictItem,
    EventCreate,
    EventResponse,
    EventType,
    EventUpdate,
)
from app.services.event_service import EventService

router = APIRouter()


def _require_tz(value: datetime) -> datetime:
    if value.utcoffset() is None:
        raise InvalidResourceStateError("Timestamps must include a timezone.")
    return value


@router.get("", response_model=list[EventResponse])
def list_events(
    uid: str = Depends(get_current_uid),
    service: EventService = Depends(get_event_service),
) -> list[StudyEvent]:
    return service.list(uid)


@router.get("/conflicts", response_model=ConflictCheckResponse)
def check_conflicts(
    starts_at: datetime,
    ends_at: datetime | None = None,
    event_type: EventType = "other",
    exclude_id: UUID | None = Query(default=None),
    uid: str = Depends(get_current_uid),
    service: EventService = Depends(get_event_service),
) -> ConflictCheckResponse:
    """Simulation : indique les conflits d'un créneau sans rien enregistrer."""
    found = service.check_conflicts(
        uid,
        event_type=event_type,
        starts_at=_require_tz(starts_at),
        ends_at=_require_tz(ends_at) if ends_at else None,
        exclude_event_id=exclude_id,
    )
    return ConflictCheckResponse(
        has_conflicts=bool(found),
        conflicts=[
            ConflictItem(
                kind=item.kind,  # type: ignore[arg-type]
                id=item.id,
                title=item.title,
                starts_at=item.starts_at,
                ends_at=item.ends_at,
            )
            for item in found
        ],
    )


@router.post("", response_model=EventResponse, status_code=status.HTTP_201_CREATED)
def create_event(
    payload: EventCreate,
    force: bool = Query(
        default=False, description="Enregistrer malgré un conflit d'horaire."
    ),
    uid: str = Depends(get_current_uid),
    service: EventService = Depends(get_event_service),
) -> StudyEvent:
    return service.create(uid, payload.model_dump(), force=force)


@router.get("/{resource_id}", response_model=EventResponse)
def read_event(
    resource_id: UUID,
    uid: str = Depends(get_current_uid),
    service: EventService = Depends(get_event_service),
) -> StudyEvent:
    return service.get(resource_id, uid)


@router.put("/{resource_id}", response_model=EventResponse)
def update_event(
    resource_id: UUID,
    payload: EventUpdate,
    force: bool = Query(
        default=False, description="Enregistrer malgré un conflit d'horaire."
    ),
    uid: str = Depends(get_current_uid),
    service: EventService = Depends(get_event_service),
) -> StudyEvent:
    return service.update(
        resource_id, uid, payload.model_dump(exclude_unset=True), force=force
    )


@router.delete("/{resource_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_event(
    resource_id: UUID,
    uid: str = Depends(get_current_uid),
    service: EventService = Depends(get_event_service),
) -> Response:
    service.delete(resource_id, uid)
    return Response(status_code=status.HTTP_204_NO_CONTENT)
