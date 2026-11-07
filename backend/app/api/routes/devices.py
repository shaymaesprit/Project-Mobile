from uuid import UUID

from fastapi import APIRouter, Depends, Response, status

from app.api.deps import get_current_uid
from app.api.dependencies import get_device_service
from app.models.extended import NotificationDevice
from app.schemas.device import DeviceRegister, DeviceResponse
from app.services.device_service import DeviceService

router = APIRouter()


@router.post("", response_model=DeviceResponse, status_code=status.HTTP_201_CREATED)
def register_device(
    payload: DeviceRegister,
    uid: str = Depends(get_current_uid),
    service: DeviceService = Depends(get_device_service),
) -> NotificationDevice:
    return service.register(uid, payload.fcm_token, payload.platform, payload.device_name)


@router.delete("/{device_id}", status_code=status.HTTP_204_NO_CONTENT)
def unregister_device(
    device_id: UUID,
    uid: str = Depends(get_current_uid),
    service: DeviceService = Depends(get_device_service),
) -> Response:
    service.unregister(uid, device_id)
    return Response(status_code=status.HTTP_204_NO_CONTENT)
