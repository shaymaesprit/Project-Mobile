from __future__ import annotations

from datetime import datetime, timedelta, timezone
from decimal import Decimal
from typing import Any
from uuid import UUID

from app.core.exceptions import InvalidReferenceError, ResourceNotFoundError
from app.models.extended import Flashcard, FlashcardDeck
from app.repositories.flashcard_repository import FlashcardRepository


class FlashcardService:
    def __init__(self, repository: FlashcardRepository) -> None:
        self._repository = repository

    def list(self, owner_uid: str) -> list[Flashcard]:
        return self._repository.list_for_owner(owner_uid)

    def list_for_deck(self, deck_id: UUID, owner_uid: str) -> list[Flashcard]:
        self._require_deck(deck_id, owner_uid)
        return self._repository.list_for_deck(deck_id, owner_uid)

    def get(self, card_id: UUID, owner_uid: str) -> Flashcard:
        card = self._repository.get_for_owner(card_id, owner_uid)
        if card is None:
            raise ResourceNotFoundError("Flashcard not found.")
        return card

    def create(self, owner_uid: str, values: dict[str, Any]) -> Flashcard:
        values = dict(values)
        self._prepare_deck(values.get("deck_id"), values, owner_uid)
        self._validate_course(values.get("course_id"), owner_uid)
        return self._repository.create(owner_uid, values)

    def update(
        self, card_id: UUID, owner_uid: str, changes: dict[str, Any]
    ) -> Flashcard:
        card = self.get(card_id, owner_uid)
        changes = dict(changes)
        deck_id = changes.get("deck_id", card.deck_id)
        if deck_id is not None:
            deck = self._require_deck(deck_id, owner_uid)
            if deck.course_id is not None:
                if changes.get("course_id", card.course_id) not in (
                    None,
                    deck.course_id,
                ):
                    raise InvalidReferenceError(
                        "Flashcard course must match its deck course."
                    )
                changes["course_id"] = deck.course_id
        if "course_id" in changes:
            self._validate_course(changes["course_id"], owner_uid)
        return self._repository.update(card, changes)

    def delete(self, card_id: UUID, owner_uid: str) -> None:
        self._repository.delete(self.get(card_id, owner_uid))

    def review(
        self, card_id: UUID, owner_uid: str, is_correct: bool
    ) -> dict[str, Any]:
        card = self.get(card_id, owner_uid)
        reviewed_at = datetime.now(timezone.utc)
        if is_correct:
            repetitions = card.repetitions + 1
            interval_days = (
                1
                if repetitions == 1
                else 6
                if repetitions == 2
                else max(1, round(card.interval_days * float(card.ease_factor)))
            )
            card.repetitions = repetitions
            card.interval_days = interval_days
            card.ease_factor = min(Decimal("9.99"), card.ease_factor + Decimal("0.1"))
            card.due_at = reviewed_at + timedelta(days=interval_days)
        else:
            card.repetitions = 0
            card.interval_days = 0
            card.ease_factor = max(Decimal("1.30"), card.ease_factor - Decimal("0.2"))
            card.due_at = reviewed_at + timedelta(minutes=10)

        counts = self._repository.record_review(card, is_correct, reviewed_at)
        total_reviews = counts["total_reviews"]
        return {
            "flashcard": card,
            **counts,
            "accuracy_rate": (
                counts["correct_answers"] * 100.0 / total_reviews
                if total_reviews
                else None
            ),
        }

    def progress(self, deck_id: UUID, owner_uid: str) -> dict[str, Any]:
        self._require_deck(deck_id, owner_uid)
        return self._repository.deck_progress(deck_id, owner_uid)

    def _prepare_deck(
        self, deck_id: UUID | None, values: dict[str, Any], owner_uid: str
    ) -> None:
        if deck_id is None:
            return
        deck = self._require_deck(deck_id, owner_uid)
        if deck.course_id is not None:
            if values.get("course_id") not in (None, deck.course_id):
                raise InvalidReferenceError(
                    "Flashcard course must match its deck course."
                )
            values["course_id"] = deck.course_id

    def _validate_course(self, course_id: UUID | None, owner_uid: str) -> None:
        if course_id is not None and not self._repository.course_exists_for_owner(
            course_id, owner_uid
        ):
            raise InvalidReferenceError("Course not found.")

    def _require_deck(self, deck_id: UUID, owner_uid: str) -> FlashcardDeck:
        deck = self._repository.deck_for_owner(deck_id, owner_uid)
        if deck is None:
            raise ResourceNotFoundError("Flashcard deck not found.")
        return deck
