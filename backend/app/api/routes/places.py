from fastapi import APIRouter, Depends, Query

from app.api.deps import get_current_uid
from app.api.dependencies import get_places_service
from app.schemas.places import PlaceDetails, PlaceSuggestion
from app.services.places_service import PlacesService

router = APIRouter()


@router.get("/autocomplete", response_model=list[PlaceSuggestion])
def autocomplete_places(
    q: str = Query(min_length=2, max_length=120),
    session_token: str | None = Query(default=None, max_length=64),
    latitude: float | None = Query(default=None, ge=-90, le=90),
    longitude: float | None = Query(default=None, ge=-180, le=180),
    _uid: str = Depends(get_current_uid),
    service: PlacesService = Depends(get_places_service),
) -> list[PlaceSuggestion]:
    return service.autocomplete(
        q.strip(),
        session_token=session_token,
        latitude=latitude,
        longitude=longitude,
    )


@router.get("/details", response_model=PlaceDetails)
def place_details(
    place_id: str = Query(min_length=10, max_length=300),
    _uid: str = Depends(get_current_uid),
    service: PlacesService = Depends(get_places_service),
) -> PlaceDetails:
    return service.details(place_id)
