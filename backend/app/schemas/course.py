from pydantic import Field, field_validator, model_validator

from app.schemas.common import ApiSchema, CourseRead


def clean_title(value: str) -> str:
    value = value.strip()
    if not value:
        raise ValueError("Title must not be empty.")
    return value


class CourseCreate(ApiSchema):
    title: str = Field(min_length=1, max_length=160)
    code: str | None = Field(default=None, max_length=40)
    professor: str | None = Field(default=None, max_length=160)
    room: str | None = Field(default=None, max_length=100)
    color: str | None = Field(default=None, max_length=16)

    @field_validator("title")
    @classmethod
    def validate_title(cls, value: str) -> str:
        return clean_title(value)


class CourseUpdate(ApiSchema):
    title: str | None = Field(default=None, min_length=1, max_length=160)
    code: str | None = Field(default=None, max_length=40)
    professor: str | None = Field(default=None, max_length=160)
    room: str | None = Field(default=None, max_length=100)
    color: str | None = Field(default=None, max_length=16)

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
