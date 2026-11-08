"""Recherche de lieux pour le champ « lieu » d'un événement.

Trois fournisseurs, au choix via ``PLACES_PROVIDER`` :

* ``photon``   : données OpenStreetMap, gratuit, **sans clé** (service public
  de Komoot, usage raisonnable) ; conçu pour la saisie semi-automatique ;
* ``geoapify`` : OpenStreetMap, clé gratuite sans carte bancaire ;
* ``google``   : Places API (New), clé liée à un compte de facturation.

Les clés restent côté serveur : le mobile n'appelle que ce backend, authentifié
par Firebase. Si le fournisseur est indisponible, le mobile retombe sur une
saisie libre du lieu.
"""

import logging

import httpx

from app.core.exceptions import PlacesUnavailableError
from app.schemas.places import PLACE_ID_PATTERN, PlaceDetails, PlaceSuggestion

logger = logging.getLogger("studymate.places")

GOOGLE_AUTOCOMPLETE_URL = "https://places.googleapis.com/v1/places:autocomplete"
GOOGLE_DETAILS_URL = "https://places.googleapis.com/v1/places/{place_id}"
PHOTON_URL = "https://photon.komoot.io/api/"
GEOAPIFY_URL = "https://api.geoapify.com/v1/geocode/autocomplete"
USER_AGENT = "StudyMate/1.0 (projet universitaire)"
PHOTON_LANGUAGES = {"fr", "en", "de", "it"}

# Compatibilité avec les anciens noms.
AUTOCOMPLETE_URL = GOOGLE_AUTOCOMPLETE_URL


class PlacesService:
    def __init__(
        self,
        provider: str,
        api_key: str | None,
        timeout: float,
    ) -> None:
        self._provider = provider
        self._api_key = api_key
        self._timeout = timeout

    # ----- API publique ---------------------------------------------------
    def autocomplete(
        self,
        query: str,
        *,
        language: str = "fr",
        session_token: str | None = None,
        latitude: float | None = None,
        longitude: float | None = None,
    ) -> list[PlaceSuggestion]:
        if self._provider == "google":
            return self._google_autocomplete(
                query, language, session_token, latitude, longitude
            )
        if self._provider == "geoapify":
            return self._geoapify_autocomplete(query, language, latitude, longitude)
        return self._photon_autocomplete(query, language, latitude, longitude)

    def details(self, place_id: str, *, language: str = "fr") -> PlaceDetails:
        if self._provider != "google":
            raise PlacesUnavailableError(
                "Ce fournisseur renvoie déjà les coordonnées avec les suggestions."
            )
        key = self._require_key()
        if not PLACE_ID_PATTERN.match(place_id):
            raise PlacesUnavailableError("Identifiant de lieu invalide.")
        data = self._request(
            "GET",
            GOOGLE_DETAILS_URL.format(place_id=place_id),
            headers={
                "X-Goog-Api-Key": key,
                "X-Goog-FieldMask": "id,displayName,formattedAddress,location",
            },
            params={"languageCode": language},
        )
        location = data.get("location") or {}
        name = (data.get("displayName") or {}).get("text") or data.get(
            "formattedAddress"
        )
        if not name:
            raise PlacesUnavailableError("Lieu introuvable.")
        return PlaceDetails(
            place_id=place_id,
            name=str(name)[:200],
            address=data.get("formattedAddress"),
            latitude=location.get("latitude"),
            longitude=location.get("longitude"),
        )

    # ----- Photon (OpenStreetMap, sans clé) -------------------------------
    def _photon_autocomplete(
        self,
        query: str,
        language: str,
        latitude: float | None,
        longitude: float | None,
    ) -> list[PlaceSuggestion]:
        params: dict = {"q": query, "limit": 8}
        if language in PHOTON_LANGUAGES:
            params["lang"] = language
        if latitude is not None and longitude is not None:
            params["lat"] = latitude
            params["lon"] = longitude
        data = self._request(
            "GET", PHOTON_URL, params=params, headers={"User-Agent": USER_AGENT}
        )
        suggestions: list[PlaceSuggestion] = []
        for feature in data.get("features", []):
            props = feature.get("properties") or {}
            coords = (feature.get("geometry") or {}).get("coordinates") or []
            if len(coords) < 2:
                continue
            name = props.get("name") or props.get("street")
            if not name:
                continue
            street = " ".join(
                part
                for part in (props.get("housenumber"), props.get("street"))
                if part and part != name
            )
            address = ", ".join(
                dict.fromkeys(
                    str(part)
                    for part in (
                        street,
                        props.get("postcode"),
                        props.get("city") or props.get("county"),
                        props.get("state"),
                        props.get("country"),
                    )
                    if part
                )
            )
            osm_id = props.get("osm_id")
            osm_type = props.get("osm_type") or "N"
            suggestions.append(
                PlaceSuggestion(
                    place_id=f"{osm_type}{osm_id}" if osm_id else f"photon{len(suggestions)}",
                    name=str(name)[:200],
                    address=address or None,
                    latitude=float(coords[1]),
                    longitude=float(coords[0]),
                )
            )
        return suggestions

    # ----- Geoapify (OpenStreetMap, clé gratuite) --------------------------
    def _geoapify_autocomplete(
        self,
        query: str,
        language: str,
        latitude: float | None,
        longitude: float | None,
    ) -> list[PlaceSuggestion]:
        key = self._require_key()
        params: dict = {"text": query, "lang": language, "limit": 8, "apiKey": key}
        if latitude is not None and longitude is not None:
            params["bias"] = f"proximity:{longitude},{latitude}"
        data = self._request(
            "GET", GEOAPIFY_URL, params=params, headers={"User-Agent": USER_AGENT}
        )
        suggestions: list[PlaceSuggestion] = []
        for feature in data.get("features", []):
            props = feature.get("properties") or {}
            lat, lon = props.get("lat"), props.get("lon")
            name = props.get("name") or props.get("address_line1")
            if lat is None or lon is None or not name:
                continue
            suggestions.append(
                PlaceSuggestion(
                    place_id=str(props.get("place_id") or f"geo{len(suggestions)}"),
                    name=str(name)[:200],
                    address=props.get("address_line2") or props.get("formatted"),
                    latitude=float(lat),
                    longitude=float(lon),
                )
            )
        return suggestions

    # ----- Google Places (New) --------------------------------------------
    def _google_autocomplete(
        self,
        query: str,
        language: str,
        session_token: str | None,
        latitude: float | None,
        longitude: float | None,
    ) -> list[PlaceSuggestion]:
        key = self._require_key()
        body: dict = {"input": query, "languageCode": language}
        if session_token:
            body["sessionToken"] = session_token
        if latitude is not None and longitude is not None:
            body["locationBias"] = {
                "circle": {
                    "center": {"latitude": latitude, "longitude": longitude},
                    "radius": 30000.0,
                }
            }
        data = self._request(
            "POST",
            GOOGLE_AUTOCOMPLETE_URL,
            json=body,
            headers={"X-Goog-Api-Key": key},
        )
        suggestions: list[PlaceSuggestion] = []
        for item in data.get("suggestions", []):
            prediction = item.get("placePrediction") if isinstance(item, dict) else None
            if not isinstance(prediction, dict):
                continue
            place_id = prediction.get("placeId")
            structured = prediction.get("structuredFormat") or {}
            main = (structured.get("mainText") or {}).get("text")
            secondary = (structured.get("secondaryText") or {}).get("text")
            full = (prediction.get("text") or {}).get("text")
            name = main or full
            if not isinstance(place_id, str) or not name:
                continue
            suggestions.append(
                PlaceSuggestion(
                    place_id=place_id,
                    name=name[:200],
                    address=(secondary or (full if main else None)),
                )
            )
        return suggestions[:8]

    # ----- Outils ---------------------------------------------------------
    def _require_key(self) -> str:
        if not self._api_key:
            logger.warning(
                "Places provider '%s' has no API key (check backend/.env).",
                self._provider,
            )
            raise PlacesUnavailableError(
                "La recherche de lieux n’est pas configurée sur ce serveur."
            )
        return self._api_key

    def _request(self, method: str, url: str, **kwargs) -> dict:
        try:
            response = httpx.request(method, url, timeout=self._timeout, **kwargs)
            response.raise_for_status()
            data = response.json()
        except (httpx.HTTPError, ValueError) as error:
            logger.warning("Places request failed (%s)", type(error).__name__)
            raise PlacesUnavailableError(
                "La recherche de lieux est momentanément indisponible."
            ) from error
        return data if isinstance(data, dict) else {}
