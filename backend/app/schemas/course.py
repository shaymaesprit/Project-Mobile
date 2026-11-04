from datetime import time

from pydantic import Field, field_validator, model_validator

from app.schemas.common import ApiSchema, CourseRead


def clean_title(value: str) -> str:
    value = value.strip()
    if not value:
        raise ValueError("Title must not be empty.")
    return value


def validate_schedule(
    weekday: int | None,
    start_time: time | None,
    end_time: time | None,
) -> None:
    schedule_values = (weekday, start_time, end_time)
    if all(value is None for value in schedule_values):
        return
    if any(value is None for value in schedule_values):
        raise ValueError(
            "Weekday, start time, and end time must all be provided together."
        )
    if weekday is None or not 0 <= weekday <= 6:
        raise ValueError("Weekday must be between 0 (Monday) and 6 (Sunday).")
    if start_time is None or end_time is None or start_time >= end_time:
        raise ValueError("The course end time must be after its start time.")


class CourseCreate(ApiSchema):
    title: str = Field(min_length=1, max_length=160)
    code: str | None = Field(default=None, max_length=40)
    professor: str | None = Field(default=None, max_length=160)
    room: str | None = Field(default=None, max_length=100)
    color: str | None = Field(default=None, max_length=16)
    weekday: int | None = Field(default=None, ge=0, le=6)
    start_time: time | None = None
    end_time: time | None = None

    @field_validator("title")
    @classmethod
    def validate_title(cls, value: str) -> str:
        return clean_title(value)

    @model_validator(mode="after")
    def validate_course_schedule(self):
        validate_schedule(self.weekday, self.start_time, self.end_time)
        return self


class CourseUpdate(ApiSchema):
    title: str | None = Field(default=None, min_length=1, max_length=160)
    code: str | None = Field(default=None, max_length=40)
    professor: str | None = Field(default=None, max_length=160)
    room: str | None = Field(default=None, max_length=100)
    color: str | None = Field(default=None, max_length=16)
    weekday: int | None = Field(default=None, ge=0, le=6)
    start_time: time | None = None
    end_time: time | None = None

    @field_validator("title")
    @classmethod
    def validate_title(cls, value: str | None) -> str | None:
        if value is None:
            raise ValueError("Title must not be null.")
        return clean_title(value)

    @model_validator(mode="after")
    def validate_changes(self):
        if not self.model_fields_set:
            raise ValueError("At least one course field must be provided.")
        if "title" in self.model_fields_set and self.title is None:
            raise ValueError("Title must not be null.")
        return self


CourseResponse = CourseRead
