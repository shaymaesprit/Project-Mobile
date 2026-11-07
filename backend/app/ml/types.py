from dataclasses import dataclass, field
from datetime import datetime
from uuid import UUID


@dataclass(frozen=True)
class CourseRecord:
    id: UUID
    title: str
    weekday: int | None = None
    start_hour: int | None = None
    end_hour: int | None = None


@dataclass(frozen=True)
class SessionRecord:
    """A study/focus session. ``started_local`` is in the student's timezone."""

    started_local: datetime
    duration_minutes: float
    focus_rating: int | None = None
    course_id: UUID | None = None


@dataclass(frozen=True)
class TaskRecord:
    is_completed: bool
    course_id: UUID | None = None
    deadline: datetime | None = None
    completed_at: datetime | None = None
    priority: str = "medium"


@dataclass(frozen=True)
class GradeRecord:
    percent: float
    course_id: UUID | None = None
    scheduled_at: datetime | None = None


@dataclass
class StudentSnapshot:
    """Aggregated, anonymous view of one student's academic activity.

    Contains no identity data (uid, email, name, phone, photo).
    """

    now: datetime
    study_level: str | None = None
    preferred_learning_style: str | None = None
    daily_goal_minutes: int = 60
    declared_preferred_hours: list[int] = field(default_factory=list)
    declared_difficult_subjects: list[str] = field(default_factory=list)
    declared_session_minutes: int | None = None
    attendance_rate: float | None = None
    courses: list[CourseRecord] = field(default_factory=list)
    sessions: list[SessionRecord] = field(default_factory=list)
    tasks: list[TaskRecord] = field(default_factory=list)
    grades: list[GradeRecord] = field(default_factory=list)
    flashcard_reviews: int = 0
    flashcard_accuracy: float | None = None

    def course_title(self, course_id: UUID | None) -> str | None:
        for course in self.courses:
            if course.id == course_id:
                return course.title
        return None
