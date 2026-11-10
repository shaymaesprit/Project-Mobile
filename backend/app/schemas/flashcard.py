from datetime import datetime
from decimal import Decimal
from typing import Literal, Self
from uuid import UUID

from pydantic import Field, field_validator, model_validator

from app.schemas.common import ApiSchema


class FlashcardDeckCreate(ApiSchema):
    title: str = Field(min_length=1, max_length=200)
    description: str | None = Field(default=None, max_length=20_000)
    course_id: UUID | None = None
    source: Literal["manual", "ai_generated"] = "manual"

    @field_validator("title")
    @classmethod
    def normalize_title(cls, value: str) -> str:
        value = value.strip()
        if not value:
            raise ValueError("Title must not be empty.")
        return value


class FlashcardDeckUpdate(ApiSchema):
    title: str | None = Field(default=None, min_length=1, max_length=200)
    description: str | None = Field(default=None, max_length=20_000)
    course_id: UUID | None = None

    @field_validator("title")
    @classmethod
    def normalize_optional_title(cls, value: str | None) -> str | None:
        if value is None:
            return None
        value = value.strip()
        if not value:
            raise ValueError("Title must not be empty.")
        return value

    @model_validator(mode="after")
    def validate_changes(self) -> Self:
        if not self.model_fields_set:
            raise ValueError("At least one deck field must be provided.")
        if "title" in self.model_fields_set and self.title is None:
            raise ValueError("Title must not be null.")
        return self


class FlashcardDeckResponse(ApiSchema):
    id: UUID
    course_id: UUID | None
    title: str
    description: str | None
    source: Literal["manual", "ai_generated"]
    created_at: datetime
    updated_at: datetime


class FlashcardCreate(ApiSchema):
    question: str = Field(min_length=1, max_length=20_000)
    answer: str = Field(min_length=1, max_length=20_000)
    deck_id: UUID | None = None
    course_id: UUID | None = None
    due_at: datetime | None = None

    @field_validator("question", "answer")
    @classmethod
    def normalize_content(cls, value: str) -> str:
        value = value.strip()
        if not value:
            raise ValueError("Question and answer must not be empty.")
        return value


class FlashcardUpdate(ApiSchema):
    question: str | None = Field(default=None, min_length=1, max_length=20_000)
    answer: str | None = Field(default=None, min_length=1, max_length=20_000)
    deck_id: UUID | None = None
    course_id: UUID | None = None
    due_at: datetime | None = None
    interval_days: int | None = Field(default=None, ge=0)
    ease_factor: Decimal | None = Field(default=None, ge=Decimal("1.30"), le=Decimal("9.99"))
    repetitions: int | None = Field(default=None, ge=0)

    @field_validator("question", "answer")
    @classmethod
    def normalize_optional_content(cls, value: str | None) -> str | None:
        if value is None:
            return None
        value = value.strip()
        if not value:
            raise ValueError("Question and answer must not be empty.")
        return value

    @model_validator(mode="after")
    def validate_changes(self) -> Self:
        if not self.model_fields_set:
            raise ValueError("At least one flashcard field must be provided.")
        for name in (
            "question",
            "answer",
            "interval_days",
            "ease_factor",
            "repetitions",
        ):
            if name in self.model_fields_set and getattr(self, name) is None:
                raise ValueError(f"{name.replace('_', ' ').capitalize()} must not be null.")
        return self


class FlashcardResponse(ApiSchema):
    id: UUID
    deck_id: UUID | None
    course_id: UUID | None
    question: str
    answer: str
    due_at: datetime | None
    interval_days: int
    ease_factor: Decimal
    repetitions: int
    created_at: datetime
    updated_at: datetime


class FlashcardReviewCreate(ApiSchema):
    is_correct: bool


class FlashcardDeckProgress(ApiSchema):
    deck_id: UUID
    total_cards: int
    reviewed_cards: int
    mastered_cards: int
    total_reviews: int
    correct_answers: int
    incorrect_answers: int
    accuracy_rate: float | None


class FlashcardReviewResponse(ApiSchema):
    flashcard: FlashcardResponse
    total_reviews: int
    correct_answers: int
    incorrect_answers: int
    accuracy_rate: float | None


class FlashcardGenerateRequest(ApiSchema):
    """Source de la génération : une note, un PDF de cours ou un texte collé."""

    note_id: UUID | None = None
    document_id: UUID | None = None
    text: str | None = Field(default=None, max_length=20_000)
    max_cards: int = Field(default=8, ge=3, le=15)

    @model_validator(mode="after")
    def _one_source(self) -> Self:
        has_text = bool(self.text and self.text.strip())
        sources = [self.note_id is not None, self.document_id is not None, has_text]
        if sum(sources) != 1:
            raise ValueError("Provide exactly one of note_id, document_id or text.")
        return self


class FlashcardGenerateResponse(ApiSchema):
    source: Literal["ai", "rules"]
    cards: list[FlashcardResponse]
