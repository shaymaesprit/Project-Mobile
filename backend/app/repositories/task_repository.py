from uuid import UUID

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models.course import Course
from app.models.task import StudyTask


class TaskRepository:
    def __init__(self, db: Session) -> None:
        self._db = db

    def list_for_owner(self, owner_uid: str) -> list[StudyTask]:
        return list(
            self._db.scalars(
                select(StudyTask)
                .where(StudyTask.owner_uid == owner_uid)
                .order_by(
                    StudyTask.is_completed,
                    StudyTask.deadline,
                    StudyTask.created_at,
                )
            )
        )

    def get_for_owner(self, task_id: UUID, owner_uid: str) -> StudyTask | None:
        return self._db.scalar(
            select(StudyTask).where(
                StudyTask.id == task_id,
                StudyTask.owner_uid == owner_uid,
            )
        )

    def course_exists_for_owner(self, course_id: UUID, owner_uid: str) -> bool:
        return (
            self._db.scalar(
                select(Course.id).where(
                    Course.id == course_id,
                    Course.owner_uid == owner_uid,
                )
            )
            is not None
        )

    def create(self, owner_uid: str, values: dict) -> StudyTask:
        task = StudyTask(owner_uid=owner_uid, **values)
        self._db.add(task)
        self._db.commit()
        self._db.refresh(task)
        return task

    def update(self, task: StudyTask, changes: dict) -> StudyTask:
        for field, value in changes.items():
            setattr(task, field, value)
        self._db.commit()
        self._db.refresh(task)
        return task

    def delete(self, task: StudyTask) -> None:
        self._db.delete(task)
        self._db.commit()
