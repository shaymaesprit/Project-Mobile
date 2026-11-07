from fastapi import APIRouter, Depends, Response, status

from app.api.deps import (
    delete_firebase_account,
    get_current_uid,
    get_current_user,
)
from app.api.dependencies import get_user_service
from app.core.audit import audit
from app.models.user import User
from app.schemas.user import UserResponse, UserUpdate
from app.services import firebase_service
from app.services.user_service import UserService

router = APIRouter()


@router.get("/me", response_model=UserResponse)
def read_current_user(user: User = Depends(get_current_user)) -> User:
    return user


@router.put("/me", response_model=UserResponse)
def update_current_user(
    payload: UserUpdate,
    user: User = Depends(get_current_user),
    service: UserService = Depends(get_user_service),
) -> User:
    return service.update(user, payload.model_dump(exclude_unset=True))


@router.delete("/me", status_code=status.HTTP_204_NO_CONTENT)
def delete_current_user(
    uid: str = Depends(get_current_uid),
    user: User = Depends(get_current_user),
    service: UserService = Depends(get_user_service),
) -> Response:
    audit("account_deletion_requested", uid)
    cleanup = firebase_service.delete_user_cloud_data(uid)
    delete_firebase_account(uid)
    service.delete(user)
    audit(
        "account_deleted", uid,
        firestore=cleanup["firestore"], storage=cleanup["storage"],
    )
    return Response(status_code=status.HTTP_204_NO_CONTENT)
