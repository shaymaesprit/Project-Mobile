from datetime import datetime
from typing import Literal

from pydantic import Field, field_validator, model_validator

from app.schemas.common import ApiSchema

LearningStyle = Literal["visual", "auditory", "reading", "kinesthetic", "mixed"]


class ProfileCreate(ApiSchema):
    study_level: str | None = Field(default=None, max_length=80)
    specialty: str | None = Field(default=None, max_length=160)
    academic_goals: list[str] = Field(default_factory=list, max_length=20)
    preferred_learning_style: LearningStyle | None = None
    daily_study_goal_minutes: int = Field(default=60, ge=0, le=1440)
    preferences: dict = Field(default_factory=dict)


class ProfileUpdate(ApiSchema):
    study_level: str | None = Field(default=None, max_length=80)
    specialty: str | None = Field(default=None, max_length=160)
    academic_goals: list[str] | None = Field(default=None, max_length=20)
    preferred_learning_style: LearningStyle | None = None
    daily_study_goal_minutes: int | None = Field(default=None, ge=0, le=1440)
    preferences: dict | None = None

    @model_validator(mode="after")
    def validate_changes(self):
        if not self.model_fields_set:
            raise ValueError("At least one profile field must be provided.")
        if "daily_study_goal_minutes" in self.model_fields_set:
            if self.daily_study_goal_minutes is None:
                raise ValueError("Study goal must not be null.")
        if "preferences" in self.model_fields_set and self.preferences is None:
            raise ValueError("Preferences must not be null.")
        if "academic_goals" in self.model_fields_set and self.academic_goals is None:
            raise ValueError("Academic goals must not be null.")
        return self

    @field_validator("study_level", "specialty")
    @classmethod
    def normalize_optional_text(cls, value: str | None) -> str | None:
        if value is None:
            return None
        return value.strip() or None

    @field_validator("academic_goals")
    @classmethod
    def normalize_academic_goals(cls, value: list[str] | None) -> list[str] | None:
        if value is None:
            return None
        goals = [goal.strip() for goal in value]
        if any(not goal for goal in goals):
            raise ValueError("Academic goals must not be empty.")
        if any(len(goal) > 200 for goal in goals):
            raise ValueError("Academic goals must not exceed 200 characters.")
        return goals

    @field_validator("preferences")
    @classmethod
    def validate_preferences(cls, value: dict | None) -> dict | None:
        if value is not None and len(value) > 100:
            raise ValueError("Preferences may contain at most 100 entries.")
        return value


class ProfileResponse(ApiSchema):
    study_level: str | None
    specialty: str | None
    academic_goals: list[str]
    preferred_learning_style: LearningStyle | None
    daily_study_goal_minutes: int
    preferences: dict
    created_at: datetime
    updated_at: datetime
