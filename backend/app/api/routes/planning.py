"""Planificateur intelligent de tâches (déclaré avant ``/tasks/{task_id}``)."""

from fastapi import APIRouter, Depends, Query

from app.api.deps import get_current_uid
from app.api.dependencies import get_planning_service
from app.schemas.planning import TaskPlanResponse
from app.services.planning_service import PlanningService

router = APIRouter()


@router.get("/plan", response_model=TaskPlanResponse)
def plan_tasks(
    days: int = Query(default=7, ge=1, le=21),
    uid: str = Depends(get_current_uid),
    service: PlanningService = Depends(get_planning_service),
) -> dict:
    """Classe les tâches par score et les place dans les créneaux libres."""
    return service.plan(uid, days=days)
