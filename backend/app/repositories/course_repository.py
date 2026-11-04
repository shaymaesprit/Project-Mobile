from datetime import time
from uuid import UUID

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models.course import Course


class CourseRepository:
    def __init__(self, db: Session) -> None:
        self._db = db

    def list_for_owner(self, owner_uid: str) -> list[Course]:
        return list(
            self._db.scalars(
                select(Course)
                .where(Course.owner_uid == owner_uid)
                .order_by(Course.title)
            )
        )

    def list_schedule_for_owner(self, owner_uid: str) -> list[Course]:
        return list(
            self._db.scalars(
                select(Course)
                .where(
                    Course.owner_uid == owner_uid,
                    Course.weekday.is_not(None),
                )
                .order_by(Course.weekday, Course.start_time, Course.title)
            )
        )

    def has_schedule_conflict(
        self,
        owner_uid: str,
        weekday: int,
        start_time: time,
        end_time: time,
        exclude_course_id: UUID | None = None,
    ) -> bool:
        statement = select(Course.id).where(
            Course.owner_uid == owner_uid,
            Course.weekday == weekday,
            Course.start_time < end_time,
            Course.end_time > start_time,
        )
        if exclude_course_id is not None:
            statement = statement.where(Course.id != exclude_course_id)
        return self._db.scalar(statement.limit(1)) is not None

    def get_for_owner(self, course_id: UUID, owner_uid: str) -> Course | None:
        return self._db.scalar(
            select(Course).where(
                Course.id == course_id,
                Course.owner_uid == owner_uid,
            )
        )

    def create(self, owner_uid: str, values: dict) -> Course:
        course = Course(owner_uid=owner_uid, **values)
        self._db.add(course)
        self._db.commit()
        self._db.refresh(course)
        return course

    def update(self, course: Course, changes: dict) -> Course:
        for field, value in changes.items():
            setattr(course, field, value)
        self._db.commit()
        self._db.refresh(course)
        return course

    def delete(self, course: Course) -> None:
        self._db.delete(course)
        self._db.commit()
