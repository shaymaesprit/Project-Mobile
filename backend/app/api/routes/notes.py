from uuid import UUID

from fastapi import APIRouter, Depends, Response, status

from app.api.deps import get_current_user
from app.api.dependencies import get_note_service
from app.models.note import Note
from app.models.user import User
from app.schemas.note import NoteCreate, NoteResponse, NoteUpdate
from app.services.note_service import NoteService

router = APIRouter()


@router.get("", response_model=list[NoteResponse])
def list_notes(
    service: NoteService = Depends(get_note_service),
    user: User = Depends(get_current_user),
) -> list[Note]:
    return service.list_notes(user.firebase_uid)


@router.get("/{note_id}", response_model=NoteResponse)
def read_note(
    note_id: UUID,
    service: NoteService = Depends(get_note_service),
    user: User = Depends(get_current_user),
) -> Note:
    return service.get_note(note_id, user.firebase_uid)


@router.post("", response_model=NoteResponse, status_code=status.HTTP_201_CREATED)
def create_note(
    payload: NoteCreate,
    service: NoteService = Depends(get_note_service),
    user: User = Depends(get_current_user),
) -> Note:
    return service.create_note(user.firebase_uid, payload.model_dump())


@router.patch("/{note_id}", response_model=NoteResponse)
def update_note(
    note_id: UUID,
    payload: NoteUpdate,
    service: NoteService = Depends(get_note_service),
    user: User = Depends(get_current_user),
) -> Note:
    return service.update_note(
        note_id, user.firebase_uid, payload.model_dump(exclude_unset=True)
    )


@router.put("/{note_id}", response_model=NoteResponse)
def replace_note(
    note_id: UUID,
    payload: NoteUpdate,
    service: NoteService = Depends(get_note_service),
    user: User = Depends(get_current_user),
) -> Note:
    return service.update_note(
        note_id, user.firebase_uid, payload.model_dump(exclude_unset=True)
    )


@router.delete("/{note_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_note(
    note_id: UUID,
    service: NoteService = Depends(get_note_service),
    user: User = Depends(get_current_user),
) -> Response:
    service.delete_note(note_id, user.firebase_uid)
    return Response(status_code=status.HTTP_204_NO_CONTENT)
