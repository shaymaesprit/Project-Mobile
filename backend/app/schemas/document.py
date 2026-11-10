from datetime import datetime
from typing import Literal
from uuid import UUID

from pydantic import Field, field_validator

from app.schemas.common import ApiSchema


class DocumentResponse(ApiSchema):
    id: UUID
    course_id: UUID | None
    title: str
    mime_type: str | None
    file_size_bytes: int | None
    page_count: int | None
    processing_status: Literal["pending", "processing", "ready", "failed"]
    # Nombre de morceaux de texte extraits (0 = PDF scanné, sans texte).
    text_chunks: int = 0
    created_at: datetime
    updated_at: datetime


class DocumentUpdate(ApiSchema):
    title: str = Field(min_length=1, max_length=240)

    @field_validator("title")
    @classmethod
    def strip_title(cls, value: str) -> str:
        value = value.strip()
        if not value:
            raise ValueError("Title cannot be blank.")
        return value
