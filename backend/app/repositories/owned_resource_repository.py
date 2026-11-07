from typing import Any
from uuid import UUID

from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.models.course import Course


class OwnedResourceRepository:
    """Shared persistence operations for records scoped to one Firebase UID."""

    def __init__(self, db: Session, model: type[Any]) -> None:
        self._db = db
        self._model = model

    def list_for_owner(self, owner_uid: str) -> list[Any]:
        statement = select(self._model).where(self._model.owner_uid == owner_uid)
        if self._model.__tablename__ == "flashcards":
            statement = statement.order_by(self._model.due_at, self._model.created_at)
        elif self._model.__tablename__ == "evaluations":
            statement = statement.order_by(
                self._model.scheduled_at, self._model.created_at
            )
        elif self._model.__tablename__ == "events":
            statement = statement.order_by(self._model.starts_at)
        elif self._model.__tablename__ == "study_sessions":
            statement = statement.order_by(self._model.started_at.desc())
        return list(self._db.scalars(statement))

    def get_for_owner(self, resource_id: UUID, owner_uid: str) -> Any | None:
        return self._db.scalar(
            select(self._model).where(
                self._model.id == resource_id,
                self._model.owner_uid == owner_uid,
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

    def create(self, owner_uid: str, values: dict[str, Any]) -> Any:
        resource = self._model(owner_uid=owner_uid, **values)
        self._db.add(resource)
        self._db.commit()
        self._db.refresh(resource)
        return resource

    def update(self, resource: Any, changes: dict[str, Any]) -> Any:
        for field, value in changes.items():
            setattr(resource, field, value)
        if hasattr(resource, "updated_at"):
            resource.updated_at = self._db.scalar(select(func.now()))
        self._db.commit()
        self._db.refresh(resource)
        return resource

    def delete(self, resource: Any) -> None:
        self._db.delete(resource)
        self._db.commit()
