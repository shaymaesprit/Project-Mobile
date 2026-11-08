"""Détection de conflits d'horaire entre un créneau, les événements et les cours.

Règles :
* un événement sans heure de fin occupe ``DEFAULT_DURATION`` ;
* les échéances (``deadline``) sont des instants, pas des blocs : elles ne
  créent ni ne subissent de conflit ;
* les événements annulés sont ignorés ;
* les cours sont hebdomadaires (``weekday`` 0 = lundi) en heure locale de
  l'utilisateur ; chaque jour touché par le créneau est comparé.
"""

from dataclasses import dataclass
from datetime import date, datetime, time, timedelta, timezone
from uuid import UUID
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models.course import Course
from app.models.extended import StudyEvent
from app.models.user import User

DEFAULT_DURATION = timedelta(hours=1)
MAX_SPAN_DAYS = 8
NON_BLOCKING_TYPES = frozenset({"deadline"})


@dataclass(frozen=True)
class Conflict:
    kind: str  # "event" | "course"
    id: UUID
    title: str
    starts_at: datetime
    ends_at: datetime

    def as_dict(self) -> dict:
        return {
            "kind": self.kind,
            "id": str(self.id),
            "title": self.title,
            "starts_at": self.starts_at.isoformat(),
            "ends_at": self.ends_at.isoformat(),
        }


def as_utc(value: datetime) -> datetime:
    if value.tzinfo is None:
        return value.replace(tzinfo=timezone.utc)
    return value.astimezone(timezone.utc)


def effective_end(starts_at: datetime, ends_at: datetime | None) -> datetime:
    if ends_at is not None and ends_at > starts_at:
        return ends_at
    return starts_at + DEFAULT_DURATION


def overlaps(a_start: datetime, a_end: datetime, b_start: datetime, b_end: datetime) -> bool:
    return a_start < b_end and b_start < a_end


def user_timezone(db: Session, owner_uid: str) -> ZoneInfo:
    user = db.get(User, owner_uid)
    name = user.timezone if user is not None else None
    if name:
        try:
            return ZoneInfo(name)
        except (ZoneInfoNotFoundError, ValueError):
            pass
    return ZoneInfo("UTC")


def course_occurrences(
    course: Course, start: datetime, end: datetime, tz: ZoneInfo
) -> list[tuple[datetime, datetime]]:
    """Occurrences (UTC) d'un cours hebdomadaire qui touchent [start, end)."""
    if course.weekday is None or course.start_time is None or course.end_time is None:
        return []
    first = as_utc(start).astimezone(tz).date() - timedelta(days=1)
    last = as_utc(end).astimezone(tz).date() + timedelta(days=1)
    occurrences: list[tuple[datetime, datetime]] = []
    day: date = first
    while day <= last:
        if day.weekday() == course.weekday:
            begins = datetime.combine(day, _naive(course.start_time), tzinfo=tz)
            ends = datetime.combine(day, _naive(course.end_time), tzinfo=tz)
            occurrences.append(
                (begins.astimezone(timezone.utc), ends.astimezone(timezone.utc))
            )
        day += timedelta(days=1)
    return [
        (b, e)
        for b, e in occurrences
        if overlaps(b, e, as_utc(start), as_utc(end))
    ]


def _naive(value: time) -> time:
    return value.replace(tzinfo=None)


def find_conflicts(
    db: Session,
    owner_uid: str,
    *,
    event_type: str,
    starts_at: datetime,
    ends_at: datetime | None,
    exclude_event_id: UUID | None = None,
) -> list[Conflict]:
    if event_type in NON_BLOCKING_TYPES:
        return []
    start = as_utc(starts_at)
    end = as_utc(effective_end(start, as_utc(ends_at) if ends_at else None))
    if end - start > timedelta(days=MAX_SPAN_DAYS):
        end = start + timedelta(days=MAX_SPAN_DAYS)

    conflicts: list[Conflict] = []

    statement = select(StudyEvent).where(
        StudyEvent.owner_uid == owner_uid,
        StudyEvent.status != "cancelled",
        StudyEvent.event_type.notin_(NON_BLOCKING_TYPES),
        StudyEvent.starts_at < end,
        StudyEvent.starts_at > start - timedelta(days=MAX_SPAN_DAYS),
    )
    if exclude_event_id is not None:
        statement = statement.where(StudyEvent.id != exclude_event_id)
    for other in db.scalars(statement):
        other_start = as_utc(other.starts_at)
        other_end = as_utc(
            effective_end(other_start, as_utc(other.ends_at) if other.ends_at else None)
        )
        if overlaps(start, end, other_start, other_end):
            conflicts.append(
                Conflict("event", other.id, other.title, other_start, other_end)
            )

    tz = user_timezone(db, owner_uid)
    courses = db.scalars(
        select(Course).where(Course.owner_uid == owner_uid, Course.weekday.is_not(None))
    )
    for course in courses:
        for begins, finishes in course_occurrences(course, start, end, tz):
            conflicts.append(Conflict("course", course.id, course.title, begins, finishes))

    conflicts.sort(key=lambda item: item.starts_at)
    return conflicts


def describe_conflicts(conflicts: list[Conflict], tz: ZoneInfo) -> str:
    parts = []
    for item in conflicts[:3]:
        local = item.starts_at.astimezone(tz)
        local_end = item.ends_at.astimezone(tz)
        parts.append(
            f"« {item.title} » ({local:%d/%m} {local:%H:%M}–{local_end:%H:%M})"
        )
    more = len(conflicts) - 3
    suffix = f" et {more} autre(s)" if more > 0 else ""
    return "Conflit d’horaire avec " + ", ".join(parts) + suffix + "."
