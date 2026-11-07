from uuid import UUID

from fastapi import APIRouter, Depends, Query, status

from app.api.deps import get_current_uid
from app.api.dependencies import get_notification_dispatcher, get_notification_service
from app.models.extended import Notification
from app.schemas.notification import NotificationResponse
from app.services.device_service import NotificationDispatcher
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


@router.post(
    "/test", response_model=NotificationResponse, status_code=status.HTTP_201_CREATED
)
def send_test_notification(
    uid: str = Depends(get_current_uid),
    dispatcher: NotificationDispatcher = Depends(get_notification_dispatcher),
) -> Notification:
    return dispatcher.dispatch(
        uid, "system", "StudyMate", "Les notifications fonctionnent sur cet appareil."
    )


@router.put("/{notification_id}/read", response_model=NotificationResponse)
def mark_notification_read(
    notification_id: UUID,
    uid: str = Depends(get_current_uid),
    service: NotificationService = Depends(get_notification_service),
) -> Notification:
    return service.mark_read(notification_id, uid)
