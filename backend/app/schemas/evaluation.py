from datetime import datetime
from decimal import Decimal
from typing import Literal, Self
from uuid import UUID

from pydantic import Field, field_validator, model_validator

from app.schemas.common import ApiSchema

EvaluationType = Literal["exam", "quiz", "assignment", "presentation", "other"]


class EvaluationCreate(ApiSchema):
    title: str = Field(min_length=1, max_length=200)
    course_id: UUID | None = None
    evaluation_type: EvaluationType = "other"
    scheduled_at: datetime | None = None
    score: Decimal | None = Field(default=None, ge=0, max_digits=8, decimal_places=2)
    max_score: Decimal | None = Field(default=None, gt=0, max_digits=8, decimal_places=2)
    notes: str | None = Field(default=None, max_length=20_000)

    @field_validator("title")
    @classmethod
    def normalize_title(cls, value: str) -> str:
        value = value.strip()
        if not value:
            raise ValueError("Title must not be empty.")
        return value

    @model_validator(mode="after")
    def validate_score(self) -> Self:
        if (self.score is None) != (self.max_score is None):
            raise ValueError("Score and max_score must be provided together.")
        if self.score is not None and self.max_score is not None:
            if self.score > self.max_score:
                raise ValueError("Score cannot exceed max_score.")
        return self


class EvaluationUpdate(ApiSchema):
    title: str | None = Field(default=None, min_length=1, max_length=200)
    course_id: UUID | None = None
    evaluation_type: EvaluationType | None = None
    scheduled_at: datetime | None = None
    score: Decimal | None = Field(default=None, ge=0, max_digits=8, decimal_places=2)
    max_score: Decimal | None = Field(default=None, gt=0, max_digits=8, decimal_places=2)
    notes: str | None = Field(default=None, max_length=20_000)

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
            raise ValueError("At least one evaluation field must be provided.")
        if "title" in self.model_fields_set and self.title is None:
            raise ValueError("Title must not be null.")
        return self


class EvaluationResponse(ApiSchema):
    id: UUID
    course_id: UUID | None
    title: str
    evaluation_type: EvaluationType
    scheduled_at: datetime | None
    score: Decimal | None
    max_score: Decimal | None
    notes: str | None
    created_at: datetime
    updated_at: datetime


class EvaluationTrendPoint(ApiSchema):
    evaluation_id: UUID
    title: str
    date: datetime
    score: Decimal
    max_score: Decimal
    percentage: float


class CourseEvaluationAverage(ApiSchema):
    course_id: UUID | None
    average_percentage: float
    evaluation_count: int


class EvaluationSummary(ApiSchema):
    graded_count: int
    average_percentage: float | None
    course_averages: list[CourseEvaluationAverage]
    trend: list[EvaluationTrendPoint]
