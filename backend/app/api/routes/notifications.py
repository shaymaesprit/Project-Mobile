from typing import Literal
from uuid import UUID

from fastapi import APIRouter, Depends, Query, Response, status
from pydantic import BaseModel

from app.api.deps import get_current_uid
from app.api.dependencies import get_notification_dispatcher, get_notification_service
from app.models.extended import Notification
from app.schemas.notification import NotificationResponse
from app.services.device_service import NotificationDispatcher
from app.services.notification_service import NotificationService

router = APIRouter()

NotificationType = Literal["reminder", "deadline", "exam", "system"]


class UnreadCount(BaseModel):
    count: int


class MarkAllReadResult(BaseModel):
    updated: int


@router.get("", response_model=list[NotificationResponse])
def list_notifications(
    limit: int = Query(default=50, ge=1, le=100),
    offset: int = Query(default=0, ge=0),
    unread_only: bool = Query(default=False),
    type: NotificationType | None = Query(default=None),
    uid: str = Depends(get_current_uid),
    service: NotificationService = Depends(get_notification_service),
) -> list[Notification]:
    return service.list_notifications(
        uid,
        limit=limit,
        offset=offset,
        unread_only=unread_only,
        notification_type=type,
    )


@router.get("/unread-count", response_model=UnreadCount)
def unread_count(
    uid: str = Depends(get_current_uid),
    service: NotificationService = Depends(get_notification_service),
) -> UnreadCount:
    return UnreadCount(count=service.unread_count(uid))


@router.put("/read-all", response_model=MarkAllReadResult)
def mark_all_read(
    uid: str = Depends(get_current_uid),
    service: NotificationService = Depends(get_notification_service),
) -> MarkAllReadResult:
    return MarkAllReadResult(updated=service.mark_all_read(uid))


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


@router.delete("/{notification_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_notification(
    notification_id: UUID,
    uid: str = Depends(get_current_uid),
    service: NotificationService = Depends(get_notification_service),
) -> Response:
    service.delete(notification_id, uid)
    return Response(status_code=status.HTTP_204_NO_CONTENT)
