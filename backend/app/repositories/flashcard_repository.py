from datetime import datetime
from typing import Any
from uuid import UUID

from sqlalchemy import case, func, select
from sqlalchemy.orm import Session

from app.models.extended import Flashcard, FlashcardDeck, FlashcardReview
from app.repositories.owned_resource_repository import OwnedResourceRepository


class FlashcardRepository:
    def __init__(self, db: Session) -> None:
        self._db = db
        self._cards = OwnedResourceRepository(db, Flashcard)

    def list_for_owner(self, owner_uid: str) -> list[Flashcard]:
        return self._cards.list_for_owner(owner_uid)

    def list_for_deck(self, deck_id: UUID, owner_uid: str) -> list[Flashcard]:
        statement = (
            select(Flashcard)
            .where(
                Flashcard.deck_id == deck_id,
                Flashcard.owner_uid == owner_uid,
            )
            .order_by(Flashcard.created_at)
        )
        return list(self._db.scalars(statement))

    def get_for_owner(self, card_id: UUID, owner_uid: str) -> Flashcard | None:
        return self._cards.get_for_owner(card_id, owner_uid)

    def deck_for_owner(
        self, deck_id: UUID, owner_uid: str
    ) -> FlashcardDeck | None:
        return self._db.scalar(
            select(FlashcardDeck).where(
                FlashcardDeck.id == deck_id,
                FlashcardDeck.owner_uid == owner_uid,
            )
        )

    def course_exists_for_owner(self, course_id: UUID, owner_uid: str) -> bool:
        return self._cards.course_exists_for_owner(course_id, owner_uid)

    def create(self, owner_uid: str, values: dict[str, Any]) -> Flashcard:
        return self._cards.create(owner_uid, values)

    def update(self, card: Flashcard, changes: dict[str, Any]) -> Flashcard:
        return self._cards.update(card, changes)

    def delete(self, card: Flashcard) -> None:
        self._cards.delete(card)

    def record_review(
        self, card: Flashcard, is_correct: bool, reviewed_at: datetime
    ) -> dict[str, int]:
        self._db.add(
            FlashcardReview(
                owner_uid=card.owner_uid,
                flashcard_id=card.id,
                is_correct=is_correct,
                reviewed_at=reviewed_at,
            )
        )
        self._db.commit()
        self._db.refresh(card)
        return self._review_counts(card.id, card.owner_uid)

    def deck_progress(self, deck_id: UUID, owner_uid: str) -> dict[str, Any]:
        total_cards = self._db.scalar(
            select(func.count(Flashcard.id)).where(
                Flashcard.deck_id == deck_id,
                Flashcard.owner_uid == owner_uid,
            )
        )
        reviewed_cards = self._db.scalar(
            select(func.count(func.distinct(FlashcardReview.flashcard_id)))
            .join(
                Flashcard,
                (Flashcard.id == FlashcardReview.flashcard_id)
                & (Flashcard.owner_uid == FlashcardReview.owner_uid),
            )
            .where(
                Flashcard.deck_id == deck_id,
                Flashcard.owner_uid == owner_uid,
            )
        )
        mastered_cards = self._db.scalar(
            select(func.count(Flashcard.id)).where(
                Flashcard.deck_id == deck_id,
                Flashcard.owner_uid == owner_uid,
                Flashcard.repetitions >= 3,
            )
        )
        counts = self._db.execute(
            select(
                func.count(FlashcardReview.id),
                func.sum(case((FlashcardReview.is_correct, 1), else_=0)),
            )
            .join(
                Flashcard,
                (Flashcard.id == FlashcardReview.flashcard_id)
                & (Flashcard.owner_uid == FlashcardReview.owner_uid),
            )
            .where(
                Flashcard.deck_id == deck_id,
                Flashcard.owner_uid == owner_uid,
            )
        ).one()
        total_reviews = counts[0] or 0
        correct_answers = counts[1] or 0
        return {
            "deck_id": deck_id,
            "total_cards": total_cards or 0,
            "reviewed_cards": reviewed_cards or 0,
            "mastered_cards": mastered_cards or 0,
            "total_reviews": total_reviews,
            "correct_answers": correct_answers,
            "incorrect_answers": total_reviews - correct_answers,
            "accuracy_rate": (
                correct_answers * 100.0 / total_reviews if total_reviews else None
            ),
        }

    def _review_counts(self, card_id: UUID, owner_uid: str) -> dict[str, int]:
        counts = self._db.execute(
            select(
                func.count(FlashcardReview.id),
                func.sum(case((FlashcardReview.is_correct, 1), else_=0)),
            ).where(
                FlashcardReview.flashcard_id == card_id,
                FlashcardReview.owner_uid == owner_uid,
            )
        ).one()
        total_reviews = counts[0] or 0
        correct_answers = counts[1] or 0
        return {
            "total_reviews": total_reviews,
            "correct_answers": correct_answers,
            "incorrect_answers": total_reviews - correct_answers,
        }
