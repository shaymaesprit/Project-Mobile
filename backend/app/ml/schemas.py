from typing import Literal
from uuid import UUID

from pydantic import BaseModel

Sufficiency = Literal["none", "low", "sufficient"]
Status = Literal["ok", "insufficient_data"]
Period = Literal["morning", "afternoon", "evening", "night"]


class PeriodShare(BaseModel):
    period: Period
    share: float
    best_hour: int | None = None


class DifficultyIndicator(BaseModel):
    course_id: UUID | None = None
    subject: str
    level: Literal["low", "medium", "high"]
    average_grade_percent: float | None = None
    reasons: list[str]


class LearningProfileResult(BaseModel):
    model_version: str
    status: Status
    data_sufficiency: Sufficiency
    period_source: Literal["observed", "declared", "none"]
    preferred_periods: list[PeriodShare]
    preferred_learning_style: str | None
    study_level: str | None
    typical_session_minutes: int | None
    average_grade_percent: float | None
    task_completion_rate: float | None
    difficulty_indicators: list[DifficultyIndicator]
    recommendations: list[str]
    missing_data: list[str]


class DayProductivity(BaseModel):
    weekday: int
    minutes: float
    productivity: float


class HourProductivity(BaseModel):
    hour: int
    minutes: float
    productivity: float


class BehaviorResult(BaseModel):
    model_version: str
    status: Status
    window_days: int
    sessions_count: int
    study_days_per_week: float | None = None
    average_session_minutes: float | None = None
    total_study_hours: float | None = None
    task_completion_rate: float | None = None
    average_focus: float | None = None
    focus_trend: Literal["improving", "stable", "declining", "unknown"] = "unknown"
    productivity_by_weekday: list[DayProductivity] = []
    productivity_by_hour: list[HourProductivity] = []
    productivity_score: float | None = None
    classification: str | None = None
    suggestions: list[str] = []
    missing_data: list[str] = []


class Contribution(BaseModel):
    feature: str
    value: float | None
    contribution: float
    text: str


class RiskIndicator(BaseModel):
    code: str
    level: Literal["low", "medium", "high"]
    message: str


class ModelInfo(BaseModel):
    version: str
    kind: Literal["rules", "ridge"]
    trained_on: str | None = None
    mae: float | None = None


class PerformanceResult(BaseModel):
    status: Status
    model: ModelInfo | None = None
    predicted_score_percent: float | None = None
    range_low: float | None = None
    range_high: float | None = None
    confidence: Literal["low", "medium"] | None = None
    risk_indicators: list[RiskIndicator] = []
    explanation: list[Contribution] = []
    assumptions: list[str] = []
    missing_data: list[str] = []


class SuggestedSession(BaseModel):
    day_offset: int
    weekday: int
    start_hour: int
    duration_minutes: int
    subject: str | None = None
    reason: str


class AttentionSubject(BaseModel):
    course_id: UUID | None = None
    subject: str
    score: float
    reasons: list[str]


class Goals(BaseModel):
    daily_minutes: int
    weekly_minutes: int
    weekly_sessions: int
    weekly_tasks_due: int


class RecommendationsResult(BaseModel):
    mode: Literal["rules", "rules+ml"]
    cold_start: bool
    suggested_sessions: list[SuggestedSession]
    suitable_hours: list[int]
    subjects_needing_attention: list[AttentionSubject]
    learning_objectives: list[str]
    goals: Goals
    notes: list[str]
