from datetime import datetime
from typing import Literal, Self
from uuid import UUID

from pydantic import BaseModel, Field, field_validator, model_validator

from app.schemas.common import ApiSchema

AI_DISCLAIMER = (
    "Contenu généré par une IA : il peut contenir des erreurs. "
    "Vérifie-le avant de t’y fier."
)
RULES_NOTICE = "Suggestion calculée à partir de règles simples, sans IA générative."

Category = Literal["study", "schedule", "revision", "organization", "wellbeing", "other"]
Priority = Literal["low", "medium", "high"]


class ConsentRead(ApiSchema):
    granted: bool
    granted_at: datetime | None = None


class ConsentUpdate(ApiSchema):
    granted: bool


class ChatRequest(ApiSchema):
    message: str = Field(min_length=1, max_length=1000)

    @field_validator("message")
    @classmethod
    def strip_message(cls, value: str) -> str:
        value = value.strip()
        if not value:
            raise ValueError("Message must not be empty.")
        return value


class ChatResponse(ApiSchema):
    reply: str
    ai_generated: bool = True
    disclaimer: str = AI_DISCLAIMER


class RecommendationDraft(BaseModel):
    """Strict schema every LLM recommendation must satisfy."""

    title: str = Field(min_length=3, max_length=200)
    description: str = Field(min_length=3, max_length=2000)
    category: Category
    priority: Priority = "medium"
    reason: str | None = Field(default=None, max_length=1000)
    suggested_action: str | None = Field(default=None, max_length=1000)

    @field_validator("title", "description")
    @classmethod
    def strip_text(cls, value: str) -> str:
        return value.strip()


class RecommendationBatch(BaseModel):
    recommendations: list[RecommendationDraft] = Field(min_length=1, max_length=5)


class AIRecommendationResponse(ApiSchema):
    id: UUID
    title: str
    description: str
    category: str
    priority: str
    reason: str | None
    suggested_action: str | None
    source: Literal["ai", "rules"]
    status: Literal["pending", "accepted", "modified", "rejected"]
    created_at: datetime
    updated_at: datetime
    ai_generated: bool = False
    notice: str = RULES_NOTICE

    @model_validator(mode="after")
    def label_origin(self) -> Self:
        self.ai_generated = self.source == "ai"
        self.notice = AI_DISCLAIMER if self.ai_generated else RULES_NOTICE
        return self


class AIRecommendationUpdate(ApiSchema):
    status: Literal["accepted", "modified", "rejected"]
    title: str | None = Field(default=None, min_length=3, max_length=200)
    description: str | None = Field(default=None, min_length=3, max_length=2000)
    suggested_action: str | None = Field(default=None, max_length=1000)

    @model_validator(mode="after")
    def validate_edits(self) -> Self:
        edited = {"title", "description", "suggested_action"} & self.model_fields_set
        if self.status == "modified" and not edited:
            raise ValueError("A modified recommendation needs at least one edited field.")
        if self.status != "modified" and edited:
            raise ValueError("Edits are only allowed with status 'modified'.")
        return self


class AIInsightResponse(ApiSchema):
    id: UUID
    insight_type: str
    title: str
    body: str
    evidence: dict
    generated_at: datetime
    expires_at: datetime | None
    ai_generated: bool = False
    notice: str = RULES_NOTICE

    @model_validator(mode="after")
    def label_origin(self) -> Self:
        self.ai_generated = (self.evidence or {}).get("source") == "ai"
        self.notice = AI_DISCLAIMER if self.ai_generated else RULES_NOTICE
        return self
