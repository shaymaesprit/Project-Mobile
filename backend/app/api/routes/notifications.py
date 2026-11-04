from uuid import UUID

from fastapi import APIRouter, Depends, Query

from app.api.deps import get_current_uid
from app.api.dependencies import get_notification_service
from app.models.extended import Notification
from app.schemas.notification import NotificationResponse
from app.services.notification_service import NotificationService

router = APIRouter()


@router.get("", response_model=list[NotificationResponse])
def list_notifications(
    limit: int = Query(default=50, ge=1, le=100),
    offset: int = Query(default=0, ge=0),
    uid: str = Depends(get_current_uid),
    service: NotificationService = Depends(get_notification_service),
) -> list[Notification]:
    return service.list_notifications(uid, limit=limit, offset=offset)


@router.put("/{notification_id}/read", response_model=NotificationResponse)
def mark_notification_read(
    notification_id: UUID,
    uid: str = Depends(get_current_uid),
    service: NotificationService = Depends(get_notification_service),
) -> Notification:
    return service.mark_read(notification_id, uid)
