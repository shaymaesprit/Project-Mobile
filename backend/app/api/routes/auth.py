from fastapi import APIRouter, Depends, Request, Response, status

from app.api.deps import (
    get_current_uid,
    get_current_user,
    revoke_firebase_sessions,
)
from app.core.audit import audit
from app.models.user import User
from app.schemas.auth import SessionRead
from app.schemas.common import UserRead

router = APIRouter()


@router.get("/me", response_model=UserRead)
def read_current_user(user: User = Depends(get_current_user)) -> User:
    return user


@router.get(
    "/session",
    response_model=SessionRead,
    summary="Describe the verified Firebase session",
)
def read_session(
    request: Request,
    uid: str = Depends(get_current_uid),
) -> SessionRead:
    claims = getattr(request.state, "firebase_claims", {})
    firebase = claims.get("firebase")
    provider = firebase.get("sign_in_provider") if isinstance(firebase, dict) else None
    expires_at = claims.get("exp")
    return SessionRead(
        firebase_uid=uid,
        email=claims.get("email") if isinstance(claims.get("email"), str) else None,
        email_verified=claims.get("email_verified") is True,
        sign_in_provider=provider if isinstance(provider, str) else None,
        expires_at=expires_at if isinstance(expires_at, int) else None,
    )


@router.post(
    "/logout-all",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Revoke every refresh token of the authenticated user",
)
def logout_all_sessions(uid: str = Depends(get_current_uid)) -> Response:
    revoke_firebase_sessions(uid)
    audit("logout_all_sessions", uid)
    return Response(status_code=status.HTTP_204_NO_CONTENT)
