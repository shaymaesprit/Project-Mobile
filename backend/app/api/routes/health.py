from fastapi import APIRouter, Depends

from app.api.dependencies import get_health_service
from app.services.health_service import HealthService

router = APIRouter()


@router.get("/health")
def health_check(
    service: HealthService = Depends(get_health_service),
) -> dict[str, str]:
    return service.check()


@router.get("/health/database")
def database_health_check(
    service: HealthService = Depends(get_health_service),
) -> dict[str, str]:
    return service.check()
