from uuid import UUID

from pydantic import Field, field_validator, model_validator

from app.schemas.common import ApiSchema, NoteRead
from app.schemas.course import clean_title


class NoteCreate(ApiSchema):
    title: str = Field(min_length=1, max_length=200)
    content: str = Field(default="", max_length=100_000)
    course_id: UUID | None = None

    @field_validator("title")
    @classmethod
    def validate_title(cls, value: str) -> str:
        return clean_title(value)


class NoteUpdate(ApiSchema):
    title: str | None = Field(default=None, min_length=1, max_length=200)
    content: str | None = Field(default=None, max_length=100_000)
    course_id: UUID | None = None

    @field_validator("title")
    @classmethod
    def validate_title(cls, value: str | None) -> str | None:
        if value is None:
            raise ValueError("Title must not be null.")
        return clean_title(value)

    @field_validator("content")
    @classmethod
    def validate_content(cls, value: str | None) -> str:
        if value is None:
            raise ValueError("Content must not be null.")
        return value

    @model_validator(mode="after")
    def validate_changes(self):
        if not self.model_fields_set:
            raise ValueError("At least one note field must be provided.")
        for field in ("title", "content"):
            if field in self.model_fields_set and getattr(self, field) is None:
                raise ValueError(f"{field.capitalize()} must not be null.")
        return self


NoteResponse = NoteRead
