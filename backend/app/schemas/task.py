from datetime import datetime
from typing import Literal
from uuid import UUID

from pydantic import Field, field_validator, model_validator

from app.schemas.common import ApiSchema, TaskRead
from app.schemas.course import clean_title


class TaskCreate(ApiSchema):
    title: str = Field(min_length=1, max_length=200)
    description: str | None = None
    priority: Literal["low", "medium", "high"] = "medium"
    deadline: datetime | None = None
    course_id: UUID | None = None

    @field_validator("title")
    @classmethod
    def validate_title(cls, value: str) -> str:
        return clean_title(value)


class TaskUpdate(ApiSchema):
    title: str | None = Field(default=None, min_length=1, max_length=200)
    description: str | None = None
    priority: Literal["low", "medium", "high"] | None = None
    deadline: datetime | None = None
    course_id: UUID | None = None
    is_completed: bool | None = None

    @field_validator("title")
    @classmethod
    def validate_title(cls, value: str | None) -> str | None:
        if value is None:
            raise ValueError("Title must not be null.")
        return clean_title(value)

    @field_validator("priority")
    @classmethod
    def validate_priority(
        cls, value: Literal["low", "medium", "high"] | None
    ) -> Literal["low", "medium", "high"]:
        if value is None:
            raise ValueError("Priority must not be null.")
        return value

    @model_validator(mode="after")
    def validate_changes(self):
        if not self.model_fields_set:
            raise ValueError("At least one task field must be provided.")
        for field in ("title", "priority", "is_completed"):
            if field in self.model_fields_set and getattr(self, field) is None:
                raise ValueError(f"{field.replace('_', ' ').capitalize()} must not be null.")
        return self


TaskResponse = TaskRead
