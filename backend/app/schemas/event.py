from datetime import datetime
from typing import Literal, Self
from uuid import UUID

from pydantic import Field, field_validator, model_validator

from app.schemas.common import ApiSchema

EventType = Literal["class", "study", "exam", "deadline", "personal", "other"]
EventStatus = Literal["planned", "done", "cancelled"]

MAX_REMINDERS = 5
MAX_REMINDER_OFFSET_MINUTES = 7 * 24 * 60


def normalize_offsets(value: list[int] | None) -> list[int] | None:
    """Dédoublonne, trie (du plus lointain au plus proche) et borne les rappels."""
    if value is None:
        return None
    unique = sorted({int(item) for item in value}, reverse=True)
    if len(unique) > MAX_REMINDERS:
        raise ValueError(f"At most {MAX_REMINDERS} reminders are allowed.")
    if any(item < 0 or item > MAX_REMINDER_OFFSET_MINUTES for item in unique):
        raise ValueError("Reminder offsets must be between 0 and 7 days (in minutes).")
    return unique


class EventCreate(ApiSchema):
    title: str = Field(min_length=1, max_length=200)
    description: str | None = Field(default=None, max_length=20_000)
    course_id: UUID | None = None
    event_type: EventType = "other"
    starts_at: datetime
    ends_at: datetime | None = None
    location: str | None = Field(default=None, max_length=200)
    latitude: float | None = Field(default=None, ge=-90, le=90)
    longitude: float | None = Field(default=None, ge=-180, le=180)
    status: EventStatus = "planned"
    reminder_offsets: list[int] = Field(default_factory=list)

    @field_validator("reminder_offsets")
    @classmethod
    def check_offsets(cls, value: list[int]) -> list[int]:
        return normalize_offsets(value) or []

    @field_validator("title")
    @classmethod
    def normalize_title(cls, value: str) -> str:
        value = value.strip()
        if not value:
            raise ValueError("Title must not be empty.")
        return value

    @field_validator("starts_at", "ends_at")
    @classmethod
    def require_timezone(cls, value: datetime | None) -> datetime | None:
        if value is not None and value.utcoffset() is None:
            raise ValueError("Event timestamps must include a timezone.")
        return value

    @model_validator(mode="after")
    def validate_range(self) -> Self:
        if self.ends_at is not None and self.ends_at < self.starts_at:
            raise ValueError("ends_at must be greater than or equal to starts_at.")
        return self


class EventUpdate(ApiSchema):
    title: str | None = Field(default=None, min_length=1, max_length=200)
    description: str | None = Field(default=None, max_length=20_000)
    course_id: UUID | None = None
    event_type: EventType | None = None
    starts_at: datetime | None = None
    ends_at: datetime | None = None
    location: str | None = Field(default=None, max_length=200)
    latitude: float | None = Field(default=None, ge=-90, le=90)
    longitude: float | None = Field(default=None, ge=-180, le=180)
    status: EventStatus | None = None
    reminder_offsets: list[int] | None = None

    @field_validator("reminder_offsets")
    @classmethod
    def check_optional_offsets(cls, value: list[int] | None) -> list[int] | None:
        return normalize_offsets(value)

    @field_validator("title")
    @classmethod
    def normalize_optional_title(cls, value: str | None) -> str | None:
        if value is None:
            return None
        value = value.strip()
        if not value:
            raise ValueError("Title must not be empty.")
        return value

    @field_validator("starts_at", "ends_at")
    @classmethod
    def require_optional_timezone(cls, value: datetime | None) -> datetime | None:
        if value is not None and value.utcoffset() is None:
            raise ValueError("Event timestamps must include a timezone.")
        return value

    @model_validator(mode="after")
    def validate_changes(self) -> Self:
        if not self.model_fields_set:
            raise ValueError("At least one event field must be provided.")
        if "title" in self.model_fields_set and self.title is None:
            raise ValueError("Title must not be null.")
        if "starts_at" in self.model_fields_set and self.starts_at is None:
            raise ValueError("starts_at must not be null.")
        if "status" in self.model_fields_set and self.status is None:
            raise ValueError("status must not be null.")
        if (
            "reminder_offsets" in self.model_fields_set
            and self.reminder_offsets is None
        ):
            raise ValueError("reminder_offsets must not be null.")
        return self


class EventResponse(ApiSchema):
    id: UUID
    course_id: UUID | None
    title: str
    description: str | None
    event_type: EventType
    starts_at: datetime
    ends_at: datetime | None
    location: str | None
    latitude: float | None = None
    longitude: float | None = None
    status: EventStatus = "planned"
    reminder_offsets: list[int] = Field(default_factory=list)
    created_at: datetime
    updated_at: datetime


class ConflictItem(ApiSchema):
    kind: Literal["event", "course"]
    id: UUID
    title: str
    starts_at: datetime
    ends_at: datetime


class ConflictCheckResponse(ApiSchema):
    has_conflicts: bool
    conflicts: list[ConflictItem]


class EventDraft(ApiSchema):
    """Événement proposé par l'IA à partir d'une phrase ; jamais enregistré tel quel."""

    title: str = Field(min_length=1, max_length=200)
    event_type: EventType = "other"
    starts_at: datetime
    ends_at: datetime | None = None
    location: str | None = Field(default=None, max_length=200)
    description: str | None = Field(default=None, max_length=2000)
    ai_generated: bool = True
