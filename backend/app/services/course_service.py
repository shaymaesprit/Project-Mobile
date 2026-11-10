from datetime import time
from uuid import UUID

from app.core.exceptions import (
    CourseScheduleConflictError,
    InvalidResourceStateError,
    ResourceNotFoundError,
)
from app.models.course import Course
from app.repositories.course_repository import CourseRepository
from app.schemas.course import validate_schedule


class CourseService:
    def __init__(self, repository: CourseRepository) -> None:
        self._repository = repository

    def list_courses(
        self,
        owner_uid: str,
        semestre: str | None = None,
        type_cours: str | None = None,
    ) -> list[Course]:
        return self._repository.list_for_owner(owner_uid, semestre=semestre, type_cours=type_cours)

    def list_schedule(self, owner_uid: str) -> list[Course]:
        return self._repository.list_schedule_for_owner(owner_uid)

    def get_course(self, course_id: UUID, owner_uid: str) -> Course:
        course = self._repository.get_for_owner(course_id, owner_uid)
        if course is None:
            raise ResourceNotFoundError("Course not found.")
        return course

    def create_course(self, owner_uid: str, values: dict) -> Course:
        self._validate_schedule(owner_uid, values)
        return self._repository.create(owner_uid, values)

    def update_course(
        self, course_id: UUID, owner_uid: str, changes: dict
    ) -> Course:
        course = self.get_course(course_id, owner_uid)
        merged_schedule = {
            "weekday": changes.get("weekday", course.weekday),
            "start_time": changes.get("start_time", course.start_time),
            "end_time": changes.get("end_time", course.end_time),
        }
        self._validate_schedule(
            owner_uid,
            merged_schedule,
            exclude_course_id=course.id,
        )
        return self._repository.update(course, changes)

    def delete_course(self, course_id: UUID, owner_uid: str) -> None:
        course = self.get_course(course_id, owner_uid)
        self._repository.delete(course)

    def get_course_stats(self, course_id: UUID, owner_uid: str):
        from app.schemas.schedule import CourseStats
        course = self.get_course(course_id, owner_uid)
        duration_minutes = 0
        if course.start_time and course.end_time:
            start = course.start_time.hour * 60 + course.start_time.minute
            end = course.end_time.hour * 60 + course.end_time.minute
            duration_minutes = max(0, end - start)
        hours_per_week = duration_minutes / 60.0
        return CourseStats(
            course_id=course.id,
            title=course.title,
            hours_per_week=hours_per_week,
            percentage=100.0,
        )

    def _validate_schedule(
        self,
        owner_uid: str,
        values: dict,
        exclude_course_id: UUID | None = None,
    ) -> None:
        weekday = values.get("weekday")
        start_time = values.get("start_time")
        end_time = values.get("end_time")
        try:
            validate_schedule(weekday, start_time, end_time)
        except ValueError as error:
            raise InvalidResourceStateError(str(error)) from error

        if weekday is None:
            return
        if not isinstance(weekday, int) or not isinstance(start_time, time) or not isinstance(
            end_time, time
        ):
            raise InvalidResourceStateError(
                "Weekday, start time, and end time must all be provided together."
            )
        if self._repository.has_schedule_conflict(
            owner_uid,
            weekday,
            start_time,
            end_time,
            exclude_course_id,
        ):
            raise CourseScheduleConflictError(
                "This course overlaps another course in your weekly schedule."
            )
