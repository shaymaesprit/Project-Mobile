import firebase_admin
from fastapi import Depends, HTTPException, Request, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from firebase_admin import auth as firebase_auth
from firebase_admin import credentials
from firebase_admin.exceptions import FirebaseError
from google.auth.exceptions import DefaultCredentialsError
from sqlalchemy.orm import Session

from app.core.config import get_settings
from app.database.session import get_db
from app.models.user import User
from app.repositories.user_repository import UserRepository
from app.services.user_service import UserService

bearer_scheme = HTTPBearer(auto_error=False)


def _firebase_app() -> firebase_admin.App:
    settings = get_settings()
    if not settings.firebase_project_id:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Firebase Admin is not configured on the backend.",
        )

    try:
        return firebase_admin.get_app()
    except ValueError:
        try:
            credential = (
                credentials.Certificate(settings.google_application_credentials)
                if settings.google_application_credentials
                else credentials.ApplicationDefault()
            )
            return firebase_admin.initialize_app(
                credential=credential,
                options={"projectId": settings.firebase_project_id},
            )
        except (DefaultCredentialsError, OSError, ValueError, FirebaseError) as error:
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail="Firebase Admin credentials are unavailable on the backend.",
            ) from error


def get_current_uid(
    request: Request,
    credentials: HTTPAuthorizationCredentials | None = Depends(bearer_scheme),
) -> str:
    if credentials is None or credentials.scheme.lower() != "bearer":
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="A Firebase ID token is required.",
            headers={"WWW-Authenticate": "Bearer"},
        )

    try:
        decoded_token = firebase_auth.verify_id_token(
            credentials.credentials,
            app=_firebase_app(),
            check_revoked=True,
        )
    except (firebase_auth.ExpiredIdTokenError, firebase_auth.RevokedIdTokenError) as error:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="The Firebase ID token has expired or been revoked.",
            headers={"WWW-Authenticate": "Bearer"},
        ) from error
    except firebase_auth.InvalidIdTokenError as error:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="The Firebase ID token is invalid.",
            headers={"WWW-Authenticate": "Bearer"},
        ) from error
    except (DefaultCredentialsError, FirebaseError, ValueError) as error:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Firebase token verification is currently unavailable.",
        ) from error

    uid = decoded_token.get("uid")
    if not isinstance(uid, str) or not uid:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="The Firebase ID token does not contain a valid user ID.",
            headers={"WWW-Authenticate": "Bearer"},
        )
    request.state.firebase_claims = decoded_token
    return uid


def get_current_user(
    request: Request,
    uid: str = Depends(get_current_uid),
    db: Session = Depends(get_db),
) -> User:
    db.info["firebase_uid"] = uid
    claims = getattr(request.state, "firebase_claims", {})
    initial_profile = {
        field: claims.get(claim)
        for field, claim in (
            ("email", "email"),
            ("display_name", "name"),
            ("photo_url", "picture"),
        )
        if isinstance(claims.get(claim), str)
    }
    return UserService(UserRepository(db)).get_or_create(uid, initial_profile)


def delete_firebase_account(uid: str) -> None:
    try:
        firebase_auth.delete_user(uid, app=_firebase_app())
    except firebase_auth.UserNotFoundError:
        return
    except (DefaultCredentialsError, FirebaseError, ValueError) as error:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="The Firebase account could not be deleted.",
        ) from error
