import re

from pydantic import Field, field_validator

from app.schemas.common import ApiSchema

PLACE_ID_PATTERN = re.compile(r"^[A-Za-z0-9_-]{10,300}$")


class PlaceSuggestion(ApiSchema):
    place_id: str
    name: str
    address: str | None = None
    # Renseignées quand le fournisseur les donne d'emblée (Photon, Geoapify) :
    # le mobile n'a alors pas besoin d'appeler /places/details.
    latitude: float | None = None
    longitude: float | None = None


class PlaceDetails(ApiSchema):
    place_id: str
    name: str
    address: str | None = None
    latitude: float | None = None
    longitude: float | None = None


class PlaceAutocompleteQuery(ApiSchema):
    q: str = Field(min_length=2, max_length=120)

    @field_validator("q")
    @classmethod
    def strip_query(cls, value: str) -> str:
        value = value.strip()
        if len(value) < 2:
            raise ValueError("Query too short.")
        return value
