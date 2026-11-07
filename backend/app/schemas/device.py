from datetime import datetime
from typing import Literal
from uuid import UUID

from pydantic import Field, field_validator

from app.schemas.common import ApiSchema


class DeviceRegister(ApiSchema):
    fcm_token: str = Field(min_length=20, max_length=4096)
    platform: Literal["android", "ios", "web"]
    device_name: str | None = Field(default=None, max_length=160)

    @field_validator("fcm_token")
    @classmethod
    def strip_token(cls, value: str) -> str:
        value = value.strip()
        if len(value) < 20:
            raise ValueError("Invalid FCM token.")
        return value

    @field_validator("device_name")
    @classmethod
    def strip_name(cls, value: str | None) -> str | None:
        return (value.strip() or None) if value is not None else None


class DeviceResponse(ApiSchema):
    id: UUID
    platform: str
    device_name: str | None
    last_seen_at: datetime
    created_at: datetime
