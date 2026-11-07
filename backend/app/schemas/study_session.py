from datetime import datetime
from typing import Self
from uuid import UUID

from pydantic import Field, field_validator, model_validator

from app.schemas.common import ApiSchema

MAX_SESSION_SECONDS = 24 * 3600


class StudySessionCreate(ApiSchema):
    course_id: UUID | None = None
    started_at: datetime
    ended_at: datetime | None = None
    duration_seconds: int | None = Field(default=None, ge=1, le=MAX_SESSION_SECONDS)
    focus_rating: int | None = Field(default=None, ge=1, le=5)
    notes: str | None = Field(default=None, max_length=5_000)

    @field_validator("started_at", "ended_at")
    @classmethod
    def require_timezone(cls, value: datetime | None) -> datetime | None:
        if value is not None and value.utcoffset() is None:
            raise ValueError("Session timestamps must include a timezone.")
        return value

    @model_validator(mode="after")
    def validate_range(self) -> Self:
        if self.ended_at is not None:
            if self.ended_at < self.started_at:
                raise ValueError("ended_at must be greater than or equal to started_at.")
            if self.duration_seconds is None:
                seconds = int((self.ended_at - self.started_at).total_seconds())
                if not 1 <= seconds <= MAX_SESSION_SECONDS:
                    raise ValueError("Session duration must be between 1 second and 24 hours.")
                self.duration_seconds = seconds
        if self.duration_seconds is None:
            raise ValueError("Provide duration_seconds or ended_at.")
        return self


class StudySessionResponse(ApiSchema):
    id: UUID
    course_id: UUID | None
    started_at: datetime
    ended_at: datetime | None
    duration_seconds: int | None
    focus_rating: int | None
    notes: str | None
    created_at: datetime
