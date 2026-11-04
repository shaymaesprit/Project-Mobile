from datetime import datetime
from decimal import Decimal
from typing import Self
from uuid import UUID

from pydantic import Field, field_validator, model_validator

from app.schemas.common import ApiSchema


class FlashcardCreate(ApiSchema):
    question: str = Field(min_length=1, max_length=20_000)
    answer: str = Field(min_length=1, max_length=20_000)
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
        for name in ("question", "answer", "interval_days", "ease_factor", "repetitions"):
            if name in self.model_fields_set and getattr(self, name) is None:
                raise ValueError(f"{name.replace('_', ' ').capitalize()} must not be null.")
        return self


class FlashcardResponse(ApiSchema):
    id: UUID
    course_id: UUID | None
    question: str
    answer: str
    due_at: datetime | None
    interval_days: int
    ease_factor: Decimal
    repetitions: int
    created_at: datetime
    updated_at: datetime
