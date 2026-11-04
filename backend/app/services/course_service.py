from uuid import UUID

from app.core.exceptions import ResourceNotFoundError
from app.models.course import Course
from app.repositories.course_repository import CourseRepository


class CourseService:
    def __init__(self, repository: CourseRepository) -> None:
        self._repository = repository

    def list_courses(self, owner_uid: str) -> list[Course]:
        return self._repository.list_for_owner(owner_uid)

    def get_course(self, course_id: UUID, owner_uid: str) -> Course:
        course = self._repository.get_for_owner(course_id, owner_uid)
        if course is None:
            raise ResourceNotFoundError("Course not found.")
        return course

    def create_course(self, owner_uid: str, values: dict) -> Course:
        return self._repository.create(owner_uid, values)

    def update_course(
        self, course_id: UUID, owner_uid: str, changes: dict
    ) -> Course:
        course = self.get_course(course_id, owner_uid)
        return self._repository.update(course, changes)

    def delete_course(self, course_id: UUID, owner_uid: str) -> None:
        course = self.get_course(course_id, owner_uid)
        self._repository.delete(course)
