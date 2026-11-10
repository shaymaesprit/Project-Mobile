from uuid import UUID

from fastapi import APIRouter, Depends, Response, status

from app.api.deps import get_current_user
from app.api.dependencies import get_timetable_service
from app.models.timetable import TimetableEntry
from app.models.user import User
from app.schemas.timetable import (
    TimetableEntryCreate,
    TimetableEntryResponse,
    TimetableEntryUpdate,
)
from app.services.timetable_service import TimetableService

router = APIRouter()


@router.get("", response_model=list[TimetableEntryResponse])
def list_timetable(
    jour: int | None = None,
    course_id: UUID | None = None,
    service: TimetableService = Depends(get_timetable_service),
    user: User = Depends(get_current_user),
) -> list[TimetableEntry]:
    return service.list_entries(user.firebase_uid, jour=jour, course_id=course_id)


@router.post("", response_model=TimetableEntryResponse, status_code=status.HTTP_201_CREATED)
def create_timetable_entry(
    payload: TimetableEntryCreate,
    service: TimetableService = Depends(get_timetable_service),
    user: User = Depends(get_current_user),
) -> TimetableEntry:
    return service.create_entry(user.firebase_uid, payload.model_dump())


@router.get("/{entry_id}", response_model=TimetableEntryResponse)
def get_timetable_entry(
    entry_id: UUID,
    service: TimetableService = Depends(get_timetable_service),
    user: User = Depends(get_current_user),
) -> TimetableEntry:
    return service.get_entry(entry_id, user.firebase_uid)


@router.put("/{entry_id}", response_model=TimetableEntryResponse)
def update_timetable_entry(
    entry_id: UUID,
    payload: TimetableEntryUpdate,
    service: TimetableService = Depends(get_timetable_service),
    user: User = Depends(get_current_user),
) -> TimetableEntry:
    return service.update_entry(
        entry_id, user.firebase_uid, payload.model_dump(exclude_unset=True)
    )


@router.delete("/{entry_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_timetable_entry(
    entry_id: UUID,
    service: TimetableService = Depends(get_timetable_service),
    user: User = Depends(get_current_user),
) -> Response:
    service.delete_entry(entry_id, user.firebase_uid)
    return Response(status_code=status.HTTP_204_NO_CONTENT)
