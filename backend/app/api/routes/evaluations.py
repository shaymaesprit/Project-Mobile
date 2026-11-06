from uuid import UUID

from fastapi import APIRouter, Depends, Response, status

from app.api.deps import get_current_uid
from app.api.dependencies import get_evaluation_service
from app.models.extended import Evaluation
from app.schemas.evaluation import (
    EvaluationCreate,
    EvaluationResponse,
    EvaluationSummary,
    EvaluationUpdate,
)
from app.services.evaluation_service import EvaluationService

router = APIRouter()


@router.get("/summary", response_model=EvaluationSummary)
def read_evaluation_summary(
    uid: str = Depends(get_current_uid),
    service: EvaluationService = Depends(get_evaluation_service),
) -> dict:
    return service.summary(uid)


@router.get("", response_model=list[EvaluationResponse])
def list_evaluations(
    uid: str = Depends(get_current_uid),
    service: EvaluationService = Depends(get_evaluation_service),
) -> list[Evaluation]:
    return service.list(uid)


@router.post(
    "", response_model=EvaluationResponse, status_code=status.HTTP_201_CREATED
)
def create_evaluation(
    payload: EvaluationCreate,
    uid: str = Depends(get_current_uid),
    service: EvaluationService = Depends(get_evaluation_service),
) -> Evaluation:
    return service.create(uid, payload.model_dump())


@router.get("/{resource_id}", response_model=EvaluationResponse)
def read_evaluation(
    resource_id: UUID,
    uid: str = Depends(get_current_uid),
    service: EvaluationService = Depends(get_evaluation_service),
) -> Evaluation:
    return service.get(resource_id, uid)


@router.put("/{resource_id}", response_model=EvaluationResponse)
def update_evaluation(
    resource_id: UUID,
    payload: EvaluationUpdate,
    uid: str = Depends(get_current_uid),
    service: EvaluationService = Depends(get_evaluation_service),
) -> Evaluation:
    return service.update(resource_id, uid, payload.model_dump(exclude_unset=True))


@router.delete("/{resource_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_evaluation(
    resource_id: UUID,
    uid: str = Depends(get_current_uid),
    service: EvaluationService = Depends(get_evaluation_service),
) -> Response:
    service.delete(resource_id, uid)
    return Response(status_code=status.HTTP_204_NO_CONTENT)
