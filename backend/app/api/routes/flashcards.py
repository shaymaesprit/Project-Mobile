from uuid import UUID

from fastapi import APIRouter, Depends, Response, status

from app.api.deps import get_current_uid
from app.api.dependencies import get_flashcard_service
from app.models.extended import Flashcard
from app.schemas.flashcard import (
    FlashcardCreate,
    FlashcardResponse,
    FlashcardReviewCreate,
    FlashcardReviewResponse,
    FlashcardUpdate,
)
from app.services.flashcard_service import FlashcardService

router = APIRouter()


@router.get("", response_model=list[FlashcardResponse])
def list_flashcards(
    uid: str = Depends(get_current_uid),
    service: FlashcardService = Depends(get_flashcard_service),
) -> list[Flashcard]:
    return service.list(uid)


@router.post(
    "", response_model=FlashcardResponse, status_code=status.HTTP_201_CREATED
)
def create_flashcard(
    payload: FlashcardCreate,
    uid: str = Depends(get_current_uid),
    service: FlashcardService = Depends(get_flashcard_service),
) -> Flashcard:
    return service.create(uid, payload.model_dump())


@router.get("/{resource_id}", response_model=FlashcardResponse)
def read_flashcard(
    resource_id: UUID,
    uid: str = Depends(get_current_uid),
    service: FlashcardService = Depends(get_flashcard_service),
) -> Flashcard:
    return service.get(resource_id, uid)


@router.put("/{resource_id}", response_model=FlashcardResponse)
def update_flashcard(
    resource_id: UUID,
    payload: FlashcardUpdate,
    uid: str = Depends(get_current_uid),
    service: FlashcardService = Depends(get_flashcard_service),
) -> Flashcard:
    return service.update(resource_id, uid, payload.model_dump(exclude_unset=True))


@router.delete("/{resource_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_flashcard(
    resource_id: UUID,
    uid: str = Depends(get_current_uid),
    service: FlashcardService = Depends(get_flashcard_service),
) -> Response:
    service.delete(resource_id, uid)
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@router.post(
    "/{resource_id}/review",
    response_model=FlashcardReviewResponse,
)
def review_flashcard(
    resource_id: UUID,
    payload: FlashcardReviewCreate,
    uid: str = Depends(get_current_uid),
    service: FlashcardService = Depends(get_flashcard_service),
) -> dict:
    return service.review(resource_id, uid, payload.is_correct)
