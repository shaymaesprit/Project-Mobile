from datetime import datetime, time
from uuid import UUID

from pydantic import Field

from app.schemas.common import ApiSchema, CourseRead


# --- Stats ---

class CourseStats(ApiSchema):
    course_id: UUID
    title: str
    hours_per_week: float
    percentage: float


class ScheduleStatsResponse(ApiSchema):
    total_hours_per_week: float
    courses: list[CourseStats]


# --- Import / Export ---

class ImportedCourse(ApiSchema):
    title: str
    professor: str | None = None
    room: str | None = None
    weekday: int | None = None
    start_time: time | None = None
    end_time: time | None = None


class ImportResult(ApiSchema):
    imported: list[ImportedCourse]
    error_message: str | None = None


# --- Free Slots / Revision ---

class FreeSlot(ApiSchema):
    weekday: int
    start_time: time
    end_time: time
    duration_minutes: int


class RevisionRecommendation(ApiSchema):
    slot: FreeSlot
    suggested_course_title: str
    rationale: str


# --- Sharing ---

class TimetableShareResponse(ApiSchema):
    token: str
    qr_url: str | None
    expires_at: datetime
    is_active: bool


class PublicScheduleResponse(ApiSchema):
    owner_name: str | None
    courses: list[CourseRead]
