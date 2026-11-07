"""Builds an anonymous StudentSnapshot from the database for one verified UID."""

from datetime import datetime, timedelta, timezone
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.ml.types import (
    CourseRecord,
    GradeRecord,
    SessionRecord,
    StudentSnapshot,
    TaskRecord,
)
from app.models.course import Course
from app.models.extended import Evaluation, FlashcardReview, LearningProfile, StudySession
from app.models.task import StudyTask
from app.models.user import User

HISTORY_DAYS = 90
MAX_ROWS = 500


def _zone(name: str | None):
    if name:
        try:
            return ZoneInfo(name)
        except (ZoneInfoNotFoundError, ValueError):
            pass
    return timezone.utc


def _local(value: datetime | None, zone) -> datetime | None:
    if value is None:
        return None
    if value.tzinfo is None:
        value = value.replace(tzinfo=timezone.utc)
    return value.astimezone(zone)


def _int_list(value, low: int, high: int) -> list[int]:
    if not isinstance(value, list):
        return []
    return sorted({v for v in value if isinstance(v, int) and not isinstance(v, bool)
                   and low <= v <= high})


def build_snapshot(db: Session, uid: str, now: datetime | None = None) -> StudentSnapshot:
    user = db.get(User, uid)
    zone = _zone(user.timezone if user else None)
    local_now = _local(now or datetime.now(timezone.utc), zone)
    since = local_now - timedelta(days=HISTORY_DAYS)

    profile = db.get(LearningProfile, uid)
    preferences = (profile.preferences if profile else None) or {}

    courses = []
    for course in db.scalars(select(Course).where(Course.owner_uid == uid)):
        end_hour = None
        if course.end_time is not None:
            end_hour = course.end_time.hour + (1 if course.end_time.minute else 0)
        courses.append(
            CourseRecord(
                id=course.id,
                title=course.title,
                weekday=course.weekday,
                start_hour=None if course.start_time is None else course.start_time.hour,
                end_hour=end_hour,
            )
        )

    sessions = []
    rows = db.scalars(
        select(StudySession)
        .where(StudySession.owner_uid == uid, StudySession.started_at >= since.astimezone(timezone.utc))
        .order_by(StudySession.started_at.desc())
        .limit(MAX_ROWS)
    )
    for row in rows:
        seconds = row.duration_seconds
        if seconds is None and row.ended_at is not None:
            seconds = int((row.ended_at - row.started_at).total_seconds())
        if not seconds or seconds <= 0:
            continue
        sessions.append(
            SessionRecord(
                started_local=_local(row.started_at, zone),
                duration_minutes=seconds / 60,
                focus_rating=row.focus_rating,
                course_id=row.course_id,
            )
        )

    tasks = [
        TaskRecord(
            is_completed=row.is_completed,
            course_id=row.course_id,
            deadline=_local(row.deadline, zone),
            completed_at=_local(row.completed_at, zone),
            priority=row.priority,
        )
        for row in db.scalars(
            select(StudyTask).where(StudyTask.owner_uid == uid).limit(MAX_ROWS)
        )
    ]

    grades = []
    for row in db.scalars(
        select(Evaluation).where(Evaluation.owner_uid == uid).limit(MAX_ROWS)
    ):
        if row.score is None or not row.max_score or row.max_score <= 0:
            continue
        grades.append(
            GradeRecord(
                percent=float(row.score) / float(row.max_score) * 100,
                course_id=row.course_id,
                scheduled_at=_local(row.scheduled_at, zone),
            )
        )

    reviews = list(
        db.scalars(
            select(FlashcardReview.is_correct)
            .where(FlashcardReview.owner_uid == uid)
            .limit(MAX_ROWS)
        )
    )

    attendance = preferences.get("attendance_rate")
    if not isinstance(attendance, (int, float)) or isinstance(attendance, bool) \
            or not 0 <= attendance <= 1:
        attendance = None
    declared_minutes = preferences.get("session_minutes")
    if not isinstance(declared_minutes, int) or isinstance(declared_minutes, bool) \
            or not 5 <= declared_minutes <= 240:
        declared_minutes = None
    subjects = preferences.get("difficult_subjects")
    subjects = [s.strip() for s in subjects if isinstance(s, str) and s.strip()][:20] \
        if isinstance(subjects, list) else []

    return StudentSnapshot(
        now=local_now,
        study_level=profile.study_level if profile else None,
        preferred_learning_style=profile.preferred_learning_style if profile else None,
        daily_goal_minutes=profile.daily_study_goal_minutes if profile else 60,
        declared_preferred_hours=_int_list(preferences.get("preferred_hours"), 0, 23),
        declared_difficult_subjects=subjects,
        declared_session_minutes=declared_minutes,
        attendance_rate=attendance,
        courses=courses,
        sessions=sessions,
        tasks=tasks,
        grades=grades,
        flashcard_reviews=len(reviews),
        flashcard_accuracy=(sum(reviews) / len(reviews)) if reviews else None,
    )
