from decimal import Decimal
from typing import Any
from uuid import UUID

from app.core.exceptions import InvalidResourceStateError
from app.repositories.owned_resource_repository import OwnedResourceRepository
from app.services.owned_resource_service import OwnedResourceService


class EvaluationService(OwnedResourceService):
    def __init__(self, repository: OwnedResourceRepository) -> None:
        super().__init__(repository, "Evaluation")

    def create(self, owner_uid: str, values: dict[str, Any]) -> Any:
        self._validate_score(values.get("score"), values.get("max_score"))
        return super().create(owner_uid, values)

    def update(
        self, resource_id: UUID, owner_uid: str, changes: dict[str, Any]
    ) -> Any:
        current = self.get(resource_id, owner_uid)
        score = changes.get("score", current.score)
        max_score = changes.get("max_score", current.max_score)
        self._validate_score(score, max_score)
        return super().update(resource_id, owner_uid, changes)

    @staticmethod
    def _validate_score(score: Decimal | None, max_score: Decimal | None) -> None:
        if score is not None and max_score is not None and score > max_score:
            raise InvalidResourceStateError("Score cannot exceed max_score.")
