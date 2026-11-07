from uuid import UUID

from fastapi import APIRouter, Depends, Response, status

from app.api.deps import get_current_uid
from app.api.dependencies import get_study_session_service
from app.models.extended import StudySession
from app.schemas.study_session import StudySessionCreate, StudySessionResponse
from app.services.owned_resource_service import OwnedResourceService

router = APIRouter()


@router.get("", response_model=list[StudySessionResponse])
def list_study_sessions(
    uid: str = Depends(get_current_uid),
    service: OwnedResourceService = Depends(get_study_session_service),
) -> list[StudySession]:
    return service.list(uid)


@router.post(
    "", response_model=StudySessionResponse, status_code=status.HTTP_201_CREATED
)
def create_study_session(
    payload: StudySessionCreate,
    uid: str = Depends(get_current_uid),
    service: OwnedResourceService = Depends(get_study_session_service),
) -> StudySession:
    return service.create(uid, payload.model_dump())


@router.delete("/{resource_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_study_session(
    resource_id: UUID,
    uid: str = Depends(get_current_uid),
    service: OwnedResourceService = Depends(get_study_session_service),
) -> Response:
    service.delete(resource_id, uid)
    return Response(status_code=status.HTTP_204_NO_CONTENT)
