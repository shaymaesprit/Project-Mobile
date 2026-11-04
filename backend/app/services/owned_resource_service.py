from typing import Any
from uuid import UUID

from app.core.exceptions import InvalidReferenceError, ResourceNotFoundError
from app.repositories.owned_resource_repository import OwnedResourceRepository


class OwnedResourceService:
    """Shared ownership and validation rules for user-owned CRUD resources."""

    def __init__(self, repository: OwnedResourceRepository, label: str) -> None:
        self._repository = repository
        self._label = label

    def list(self, owner_uid: str) -> list[Any]:
        return self._repository.list_for_owner(owner_uid)

    def get(self, resource_id: UUID, owner_uid: str) -> Any:
        resource = self._repository.get_for_owner(resource_id, owner_uid)
        if resource is None:
            raise ResourceNotFoundError(f"{self._label} not found.")
        return resource

    def create(self, owner_uid: str, values: dict[str, Any]) -> Any:
        self._validate_course(values.get("course_id"), owner_uid)
        return self._repository.create(owner_uid, values)

    def update(
        self, resource_id: UUID, owner_uid: str, changes: dict[str, Any]
    ) -> Any:
        resource = self.get(resource_id, owner_uid)
        if "course_id" in changes:
            self._validate_course(changes["course_id"], owner_uid)
        return self._repository.update(resource, changes)

    def delete(self, resource_id: UUID, owner_uid: str) -> None:
        resource = self.get(resource_id, owner_uid)
        self._repository.delete(resource)

    def _validate_course(self, course_id: UUID | None, owner_uid: str) -> None:
        if course_id is not None and not self._repository.course_exists_for_owner(
            course_id, owner_uid
        ):
            raise InvalidReferenceError("Course not found.")
