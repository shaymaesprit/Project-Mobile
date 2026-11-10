from datetime import date, datetime, time
from typing import Literal
from uuid import UUID

from pydantic import Field

from app.schemas.common import ApiSchema


class HolidayRead(ApiSchema):
    date: date
    name: str
    local_name: str


class AgendaItem(ApiSchema):
    kind: Literal["course", "event"]
    id: UUID
    title: str
    starts_at: datetime
    ends_at: datetime
    room: str | None = None


class TimeWindow(ApiSchema):
    starts_at: datetime
    ends_at: datetime
    minutes: int


class AgendaDay(ApiSchema):
    date: date
    holiday: HolidayRead | None
    items: list[AgendaItem]
    cancelled: list[AgendaItem]
    free_slots: list[TimeWindow]
    conflicts: list[list[AgendaItem]]


class CourseHours(ApiSchema):
    course_id: UUID
    title: str
    hours: float


class AgendaStats(ApiSchema):
    course_hours: float
    free_hours: float
    by_course: list[CourseHours]


class WeekAgendaResponse(ApiSchema):
    week_start: date
    timezone: str
    days: list[AgendaDay]
    stats: AgendaStats


class PlannedTask(ApiSchema):
    task_id: UUID
    title: str
    priority: str
    deadline: datetime | None
    course_id: UUID | None
    score: float
    reasons: list[str]
    estimated_minutes: int
    planned_minutes: int
    status: Literal["planned", "partial", "unplanned", "overdue"]
    sessions: list[TimeWindow]


class TaskPlanResponse(ApiSchema):
    generated_at: datetime
    timezone: str
    days: int
    holidays: list[HolidayRead]
    free_minutes: int
    items: list[PlannedTask]


class TaskBreakdownRequest(ApiSchema):
    create_tasks: bool = False


class TaskBreakdownStep(ApiSchema):
    title: str
    minutes: int


class TaskBreakdownResponse(ApiSchema):
    steps: list[TaskBreakdownStep]
    created_task_ids: list[UUID] = Field(default_factory=list)


class TimetableShareRead(ApiSchema):
    id: UUID
    token: str
    qr_url: str | None
    link: str
    is_active: bool
    expires_at: datetime
    created_at: datetime | None


class PublicCourse(ApiSchema):
    title: str
    weekday: int | None
    start_time: time | None
    end_time: time | None
    room: str | None
    professor: str | None
    type_cours: str | None


class PublicTimetableResponse(ApiSchema):
    owner_name: str | None
    expires_at: datetime
    courses: list[PublicCourse]


class WikipediaResult(ApiSchema):
    title: str
    description: str | None
    extract: str
    url: str
    thumbnail: str | None
