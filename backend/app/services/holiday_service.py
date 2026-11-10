"""Jours fériés via l'API publique Nager.Date (gratuite, sans clé).

https://date.nager.at/api/v3/PublicHolidays/{year}/{countryCode}

Les résultats sont mis en cache par (année, pays) pendant 24 h. Une panne de
l'API ne casse jamais l'emploi du temps : on renvoie alors une liste vide.
"""

from __future__ import annotations

import logging
import time as clock
from dataclasses import dataclass
from datetime import date
from typing import Callable

import httpx

logger = logging.getLogger("studymate.holidays")

NAGER_URL = "https://date.nager.at/api/v3/PublicHolidays/{year}/{country}"
CACHE_SECONDS = 24 * 3600


@dataclass(frozen=True)
class Holiday:
    day: date
    name: str
    local_name: str

    def as_dict(self) -> dict:
        return {"date": self.day.isoformat(), "name": self.name, "local_name": self.local_name}


Fetcher = Callable[[int, str], list[dict]]


def _http_fetch(year: int, country: str, timeout: float = 6.0) -> list[dict]:
    response = httpx.get(
        NAGER_URL.format(year=year, country=country),
        timeout=timeout,
        headers={"Accept": "application/json"},
    )
    if response.status_code == 204:  # pays sans données
        return []
    response.raise_for_status()
    data = response.json()
    return data if isinstance(data, list) else []


class HolidayService:
    _cache: dict[tuple[int, str], tuple[float, list[Holiday]]] = {}

    def __init__(self, country: str = "TN", fetcher: Fetcher | None = None) -> None:
        self._country = country.upper()
        self._fetch = fetcher or _http_fetch

    def for_year(self, year: int) -> list[Holiday]:
        key = (year, self._country)
        cached = self._cache.get(key)
        if cached and clock.monotonic() - cached[0] < CACHE_SECONDS:
            return cached[1]
        try:
            raw = self._fetch(year, self._country)
            holidays = [
                Holiday(
                    day=date.fromisoformat(item["date"]),
                    name=str(item.get("name") or item.get("localName") or "Jour férié"),
                    local_name=str(item.get("localName") or item.get("name") or ""),
                )
                for item in raw
                if isinstance(item, dict) and item.get("date")
            ]
        except (httpx.HTTPError, ValueError, KeyError) as error:
            logger.warning("Nager.Date indisponible (%s) — aucun jour férié.", error)
            return []  # pas de mise en cache : on réessaiera plus tard
        self._cache[key] = (clock.monotonic(), holidays)
        return holidays

    def between(self, start: date, end: date) -> dict[date, Holiday]:
        """Jours fériés dans [start, end], indexés par date."""
        found: dict[date, Holiday] = {}
        for year in range(start.year, end.year + 1):
            for holiday in self.for_year(year):
                if start <= holiday.day <= end:
                    found[holiday.day] = holiday
        return found

    @classmethod
    def clear_cache(cls) -> None:
        cls._cache.clear()
