from uuid import UUID

from fastapi import APIRouter, Depends, Response, status

from app.api.deps import get_current_uid
from app.api.dependencies import get_event_service
from app.models.extended import StudyEvent
from app.schemas.event import EventCreate, EventResponse, EventUpdate
from app.services.owned_resource_service import OwnedResourceService

router = APIRouter()


@router.get("", response_model=list[EventResponse])
def list_events(
    uid: str = Depends(get_current_uid),
    service: OwnedResourceService = Depends(get_event_service),
) -> list[StudyEvent]:
    return service.list(uid)


@router.post("", response_model=EventResponse, status_code=status.HTTP_201_CREATED)
def create_event(
    payload: EventCreate,
    uid: str = Depends(get_current_uid),
    service: OwnedResourceService = Depends(get_event_service),
) -> StudyEvent:
    return service.create(uid, payload.model_dump())


@router.get("/{resource_id}", response_model=EventResponse)
def read_event(
    resource_id: UUID,
    uid: str = Depends(get_current_uid),
    service: OwnedResourceService = Depends(get_event_service),
) -> StudyEvent:
    return service.get(resource_id, uid)


@router.put("/{resource_id}", response_model=EventResponse)
def update_event(
    resource_id: UUID,
    payload: EventUpdate,
    uid: str = Depends(get_current_uid),
    service: OwnedResourceService = Depends(get_event_service),
) -> StudyEvent:
    return service.update(resource_id, uid, payload.model_dump(exclude_unset=True))


@router.delete("/{resource_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_event(
    resource_id: UUID,
    uid: str = Depends(get_current_uid),
    service: OwnedResourceService = Depends(get_event_service),
) -> Response:
    service.delete(resource_id, uid)
    return Response(status_code=status.HTTP_204_NO_CONTENT)
