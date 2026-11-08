"""Calendrier unifié : fusionne événements, cours (hebdomadaires) et tâches."""

from datetime import datetime, timedelta

from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.core.exceptions import InvalidResourceStateError
from app.models.course import Course
from app.models.extended import StudyEvent
from app.models.task import StudyTask
from app.schemas.calendar import CalendarItem
from app.services.event_conflicts import (
    as_utc,
    course_occurrences,
    user_timezone,
)

MAX_RANGE = timedelta(days=62)


class CalendarService:
    def __init__(self, db: Session) -> None:
        self._db = db

    def items(
        self,
        owner_uid: str,
        start: datetime,
        end: datetime,
        *,
        include_courses: bool = True,
        include_tasks: bool = True,
    ) -> list[CalendarItem]:
        start, end = as_utc(start), as_utc(end)
        if end <= start:
            raise InvalidResourceStateError("`to` must be after `from`.")
        if end - start > MAX_RANGE:
            raise InvalidResourceStateError("The calendar range cannot exceed 62 days.")

        items: list[CalendarItem] = []

        events = self._db.scalars(
            select(StudyEvent).where(
                StudyEvent.owner_uid == owner_uid,
                StudyEvent.starts_at < end,
                func.coalesce(StudyEvent.ends_at, StudyEvent.starts_at) >= start,
            )
        )
        for event in events:
            items.append(
                CalendarItem(
                    kind="event",
                    id=event.id,
                    title=event.title,
                    starts_at=as_utc(event.starts_at),
                    ends_at=as_utc(event.ends_at) if event.ends_at else None,
                    category=event.event_type,
                    status=event.status,
                    location=event.location,
                    course_id=event.course_id,
                )
            )

        if include_courses:
            tz = user_timezone(self._db, owner_uid)
            courses = self._db.scalars(
                select(Course).where(
                    Course.owner_uid == owner_uid, Course.weekday.is_not(None)
                )
            )
            for course in courses:
                for begins, finishes in course_occurrences(course, start, end, tz):
                    items.append(
                        CalendarItem(
                            kind="course",
                            id=course.id,
                            title=course.title,
                            starts_at=begins,
                            ends_at=finishes,
                            category="class",
                            location=course.room,
                            course_id=course.id,
                            color=course.color,
                        )
                    )

        if include_tasks:
            tasks = self._db.scalars(
                select(StudyTask).where(
                    StudyTask.owner_uid == owner_uid,
                    StudyTask.deadline.is_not(None),
                    StudyTask.deadline >= start,
                    StudyTask.deadline < end,
                )
            )
            for task in tasks:
                items.append(
                    CalendarItem(
                        kind="task",
                        id=task.id,
                        title=task.title,
                        starts_at=as_utc(task.deadline),
                        category="deadline",
                        course_id=task.course_id,
                        completed=task.is_completed,
                    )
                )

        items.sort(key=lambda item: (item.starts_at, item.kind, item.title))
        return items
