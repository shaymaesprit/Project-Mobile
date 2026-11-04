from datetime import datetime
from typing import Any
from uuid import UUID

from pydantic import Field

from app.schemas.common import ApiSchema


class NotificationResponse(ApiSchema):
    id: UUID
    notification_type: str
    title: str
    body: str
    payload: dict[str, Any]
    scheduled_at: datetime | None
    sent_at: datetime | None
    read_at: datetime | None
    created_at: datetime


class NotificationListQuery(ApiSchema):
    limit: int = Field(default=50, ge=1, le=100)
    offset: int = Field(default=0, ge=0)
