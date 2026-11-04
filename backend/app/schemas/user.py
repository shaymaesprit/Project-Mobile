from datetime import datetime

from pydantic import Field, field_validator, model_validator

from app.schemas.common import ApiSchema


class UserUpdate(ApiSchema):
    display_name: str | None = Field(default=None, max_length=160)
    photo_url: str | None = Field(default=None, max_length=2048)
    locale: str | None = Field(default=None, max_length=20)
    timezone: str | None = Field(default=None, max_length=64)

    @model_validator(mode="after")
    def validate_changes(self):
        if not self.model_fields_set:
            raise ValueError("At least one user field must be provided.")
        return self

    @field_validator("display_name", "locale", "timezone")
    @classmethod
    def normalize_optional_text(cls, value: str | None) -> str | None:
        if value is None:
            return None
        value = value.strip()
        return value or None


class UserResponse(ApiSchema):
    firebase_uid: str
    email: str | None
    display_name: str | None
    photo_url: str | None
    locale: str | None
    timezone: str | None
    created_at: datetime
    updated_at: datetime
