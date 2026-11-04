from fastapi import APIRouter, Depends

from app.api.deps import get_current_uid
from app.api.dependencies import get_profile_service
from app.models.extended import LearningProfile
from app.schemas.profile import ProfileResponse, ProfileUpdate
from app.services.profile_service import ProfileService

router = APIRouter()


@router.get("", response_model=ProfileResponse)
def read_profile(
    uid: str = Depends(get_current_uid),
    service: ProfileService = Depends(get_profile_service),
) -> LearningProfile:
    return service.get_or_create(uid)


@router.put("", response_model=ProfileResponse)
def update_profile(
    payload: ProfileUpdate,
    uid: str = Depends(get_current_uid),
    service: ProfileService = Depends(get_profile_service),
) -> LearningProfile:
    return service.update(uid, payload.model_dump(exclude_unset=True))
