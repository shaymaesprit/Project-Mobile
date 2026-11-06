from uuid import UUID

from fastapi import APIRouter, Depends, Response, status

from app.api.deps import get_current_uid
from app.api.dependencies import (
    get_flashcard_deck_service,
    get_flashcard_service,
)
from app.core.exceptions import InvalidReferenceError
from app.models.extended import Flashcard, FlashcardDeck
from app.schemas.flashcard import (
    FlashcardCreate,
    FlashcardDeckCreate,
    FlashcardDeckProgress,
    FlashcardDeckResponse,
    FlashcardDeckUpdate,
    FlashcardResponse,
)
from app.services.flashcard_service import FlashcardService
from app.services.owned_resource_service import OwnedResourceService

router = APIRouter()


@router.get("", response_model=list[FlashcardDeckResponse])
def list_decks(
    uid: str = Depends(get_current_uid),
    service: OwnedResourceService = Depends(get_flashcard_deck_service),
) -> list[FlashcardDeck]:
    return service.list(uid)


@router.post(
    "", response_model=FlashcardDeckResponse, status_code=status.HTTP_201_CREATED
)
def create_deck(
    payload: FlashcardDeckCreate,
    uid: str = Depends(get_current_uid),
    service: OwnedResourceService = Depends(get_flashcard_deck_service),
) -> FlashcardDeck:
    return service.create(uid, payload.model_dump())


@router.get("/{deck_id}", response_model=FlashcardDeckResponse)
def read_deck(
    deck_id: UUID,
    uid: str = Depends(get_current_uid),
    service: OwnedResourceService = Depends(get_flashcard_deck_service),
) -> FlashcardDeck:
    return service.get(deck_id, uid)


@router.put("/{deck_id}", response_model=FlashcardDeckResponse)
def update_deck(
    deck_id: UUID,
    payload: FlashcardDeckUpdate,
    uid: str = Depends(get_current_uid),
    service: OwnedResourceService = Depends(get_flashcard_deck_service),
) -> FlashcardDeck:
    return service.update(deck_id, uid, payload.model_dump(exclude_unset=True))


@router.delete("/{deck_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_deck(
    deck_id: UUID,
    uid: str = Depends(get_current_uid),
    service: OwnedResourceService = Depends(get_flashcard_deck_service),
) -> Response:
    service.delete(deck_id, uid)
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@router.get("/{deck_id}/cards", response_model=list[FlashcardResponse])
def list_deck_cards(
    deck_id: UUID,
    uid: str = Depends(get_current_uid),
    service: FlashcardService = Depends(get_flashcard_service),
) -> list[Flashcard]:
    return service.list_for_deck(deck_id, uid)


@router.post(
    "/{deck_id}/cards",
    response_model=FlashcardResponse,
    status_code=status.HTTP_201_CREATED,
)
def create_deck_card(
    deck_id: UUID,
    payload: FlashcardCreate,
    uid: str = Depends(get_current_uid),
    service: FlashcardService = Depends(get_flashcard_service),
) -> Flashcard:
    if payload.deck_id not in (None, deck_id):
        raise InvalidReferenceError("Flashcard deck does not match the request.")
    values = payload.model_dump()
    values["deck_id"] = deck_id
    return service.create(uid, values)


@router.get("/{deck_id}/progress", response_model=FlashcardDeckProgress)
def read_deck_progress(
    deck_id: UUID,
    uid: str = Depends(get_current_uid),
    service: FlashcardService = Depends(get_flashcard_service),
) -> dict:
    return service.progress(deck_id, uid)
