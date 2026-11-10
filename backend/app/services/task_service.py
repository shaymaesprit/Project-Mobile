from uuid import UUID
from datetime import datetime, timezone

from app.core.exceptions import InvalidReferenceError, ResourceNotFoundError
from app.models.task import StudyTask
from app.repositories.task_repository import TaskRepository


class TaskService:
    def __init__(self, repository: TaskRepository) -> None:
        self._repository = repository

    def list_tasks(self, owner_uid: str) -> list[StudyTask]:
        return self._repository.list_for_owner(owner_uid)

    def get_task(self, task_id: UUID, owner_uid: str) -> StudyTask:
        task = self._repository.get_for_owner(task_id, owner_uid)
        if task is None:
            raise ResourceNotFoundError("Task not found.")
        return task

    def create_task(self, owner_uid: str, values: dict) -> StudyTask:
        self._validate_course(values.get("course_id"), owner_uid)
        return self._repository.create(owner_uid, values)

    def update_task(
        self, task_id: UUID, owner_uid: str, changes: dict
    ) -> StudyTask:
        task = self.get_task(task_id, owner_uid)
        if "course_id" in changes:
            self._validate_course(changes["course_id"], owner_uid)
        if "is_completed" in changes:
            done = bool(changes["is_completed"])
            changes["completed_at"] = datetime.now(timezone.utc) if done else None
            # La base exige status = 'completed' ⇔ is_completed.
            changes["status"] = "completed" if done else "pending"
        return self._repository.update(task, changes)

    def delete_task(self, task_id: UUID, owner_uid: str) -> None:
        task = self.get_task(task_id, owner_uid)
        self._repository.delete(task)

    def _validate_course(self, course_id: UUID | None, owner_uid: str) -> None:
        if course_id is not None and not self._repository.course_exists_for_owner(
            course_id, owner_uid
        ):
            raise InvalidReferenceError("Course not found.")
