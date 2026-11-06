from decimal import Decimal
from typing import Any
from uuid import UUID

from app.core.exceptions import InvalidResourceStateError
from app.repositories.owned_resource_repository import OwnedResourceRepository
from app.schemas.evaluation import CourseEvaluationAverage, EvaluationTrendPoint
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

    def summary(self, owner_uid: str) -> dict[str, Any]:
        graded = [
            item
            for item in self.list(owner_uid)
            if item.score is not None and item.max_score is not None
        ]
        percentages = {
            item.id: float(item.score / item.max_score * Decimal("100"))
            for item in graded
        }
        by_course: dict[UUID | None, list[float]] = {}
        for item in graded:
            by_course.setdefault(item.course_id, []).append(percentages[item.id])

        trend = [
            EvaluationTrendPoint(
                evaluation_id=item.id,
                title=item.title,
                date=item.scheduled_at or item.created_at,
                score=item.score,
                max_score=item.max_score,
                percentage=percentages[item.id],
            )
            for item in sorted(
                graded, key=lambda evaluation: evaluation.scheduled_at or evaluation.created_at
            )
        ]
        course_averages = [
            CourseEvaluationAverage(
                course_id=course_id,
                average_percentage=sum(values) / len(values),
                evaluation_count=len(values),
            )
            for course_id, values in by_course.items()
        ]
        return {
            "graded_count": len(graded),
            "average_percentage": (
                sum(percentages.values()) / len(percentages) if percentages else None
            ),
            "course_averages": course_averages,
            "trend": trend,
        }

    @staticmethod
    def _validate_score(score: Decimal | None, max_score: Decimal | None) -> None:
        if (score is None) != (max_score is None):
            raise InvalidResourceStateError(
                "Score and max_score must be provided together."
            )
        if score is not None and max_score is not None and score > max_score:
            raise InvalidResourceStateError("Score cannot exceed max_score.")
