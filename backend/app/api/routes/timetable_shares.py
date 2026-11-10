"""Partage de l'emploi du temps par QR code (déclaré avant ``/timetable/{id}``)."""

from uuid import UUID

from fastapi import APIRouter, Depends, Query, Request, Response, status
from fastapi.responses import HTMLResponse

from app.api.deps import get_current_user
from app.api.dependencies import get_timetable_share_service
from app.core.config import get_settings
from app.models.timetable_share import TimetableShare
from app.models.user import User
from app.schemas.planning import PublicTimetableResponse, TimetableShareRead
from app.services.timetable_share_service import TimetableShareService

router = APIRouter()


def _public_base(request: Request) -> str:
    configured = get_settings().public_api_url
    if configured:
        return configured.rstrip("/")
    return str(request.base_url).rstrip("/") + "/api/v1"


@router.post("/shares", response_model=TimetableShareRead, status_code=status.HTTP_201_CREATED)
def create_share(
    request: Request,
    days: int = Query(default=7, ge=1, le=30),
    user: User = Depends(get_current_user),
    service: TimetableShareService = Depends(get_timetable_share_service),
) -> dict:
    share = service.create(user.firebase_uid, _public_base(request), days=days)
    return _share_dict(share, request)


@router.get("/shares", response_model=list[TimetableShareRead])
def list_shares(
    request: Request,
    user: User = Depends(get_current_user),
    service: TimetableShareService = Depends(get_timetable_share_service),
) -> list[dict]:
    return [_share_dict(share, request) for share in service.list_active(user.firebase_uid)]


@router.delete("/shares/{share_id}", status_code=status.HTTP_204_NO_CONTENT)
def revoke_share(
    share_id: UUID,
    user: User = Depends(get_current_user),
    service: TimetableShareService = Depends(get_timetable_share_service),
) -> Response:
    service.revoke(user.firebase_uid, share_id)
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@router.get("/shared/{token}", response_model=PublicTimetableResponse)
def read_shared(
    token: str,
    service: TimetableShareService = Depends(get_timetable_share_service),
) -> dict:
    """Lecture publique (sans connexion) d'un emploi du temps partagé."""
    return service.public_schedule(token)


@router.get("/shared/{token}/page", response_class=HTMLResponse)
def read_shared_page(
    token: str,
    service: TimetableShareService = Depends(get_timetable_share_service),
) -> HTMLResponse:
    """Page web ouverte en scannant le QR code."""
    return HTMLResponse(service.render_html(service.public_schedule(token)))


def _share_dict(share: TimetableShare, request: Request) -> dict:
    return {
        "id": share.id,
        "token": share.token,
        "qr_url": share.qr_url,
        "link": f"{_public_base(request)}/timetable/shared/{share.token}/page",
        "is_active": share.is_active,
        "expires_at": share.expires_at,
        "created_at": share.created_at,
    }
