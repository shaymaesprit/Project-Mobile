"""Gestion des événements : conflits, rappels, calendrier unifié, IA, lieux."""

import json

import pytest
from datetime import datetime, timedelta, timezone
from uuid import UUID

import httpx
from sqlalchemy import select

from app.main import app
from app.models.extended import EventReminder, Notification, StudyEvent
from app.services import places_service, reminder_service
from app.services.ai_service import LLMError, get_llm_provider

from tests.conftest import TestSession

API = "/api/v1"


def event(title="Examen BD", start="2030-03-04T10:00:00Z", end="2030-03-04T12:00:00Z", **extra):
    body = {"title": title, "starts_at": start, "ends_at": end, "event_type": "exam"}
    body.update(extra)
    return body


# ----- conflits ---------------------------------------------------------
def test_overlapping_events_conflict_unless_forced(client):
    assert client.post(f"{API}/events", json=event()).status_code == 201

    response = client.post(
        f"{API}/events",
        json=event("TD Réseaux", "2030-03-04T11:00:00Z", "2030-03-04T13:00:00Z"),
    )
    assert response.status_code == 409
    body = response.json()
    assert body["code"] == "event_schedule_conflict"
    assert "Examen BD" in body["detail"]
    assert body["conflicts"][0]["kind"] == "event"

    forced = client.post(
        f"{API}/events?force=true",
        json=event("TD Réseaux", "2030-03-04T11:00:00Z", "2030-03-04T13:00:00Z"),
    )
    assert forced.status_code == 201


def test_back_to_back_events_and_deadlines_do_not_conflict(client):
    assert client.post(f"{API}/events", json=event()).status_code == 201
    adjacent = event("Révision", "2030-03-04T12:00:00Z", "2030-03-04T13:00:00Z")
    assert client.post(f"{API}/events", json=adjacent).status_code == 201
    deadline = event(
        "Rendu projet", "2030-03-04T10:30:00Z", None, event_type="deadline"
    )
    assert client.post(f"{API}/events", json=deadline).status_code == 201


def test_update_ignores_itself_and_cancelled_events(client):
    first = client.post(f"{API}/events", json=event()).json()
    moved = client.put(
        f"{API}/events/{first['id']}",
        json={"starts_at": "2030-03-04T10:30:00Z", "ends_at": "2030-03-04T12:30:00Z"},
    )
    assert moved.status_code == 200

    client.put(f"{API}/events/{first['id']}", json={"status": "cancelled"})
    assert (
        client.post(f"{API}/events", json=event("Autre")).status_code == 201
    )


def test_conflict_dry_run_endpoint(client):
    client.post(f"{API}/events", json=event())
    response = client.get(
        f"{API}/events/conflicts",
        params={"starts_at": "2030-03-04T09:00:00Z", "ends_at": "2030-03-04T10:30:00Z"},
    )
    assert response.status_code == 200
    assert response.json()["has_conflicts"] is True

    free = client.get(
        f"{API}/events/conflicts",
        params={"starts_at": "2030-03-04T14:00:00Z", "ends_at": "2030-03-04T15:00:00Z"},
    )
    assert free.json() == {"has_conflicts": False, "conflicts": []}

    naive = client.get(
        f"{API}/events/conflicts", params={"starts_at": "2030-03-04T14:00:00"}
    )
    assert naive.status_code == 422


def test_event_conflicts_with_weekly_course_in_user_timezone(client):
    client.put(
        f"{API}/users/me", json={"display_name": "Test", "timezone": "Africa/Tunis"}
    )
    # 2030-03-04 est un lundi ; Tunis = UTC+1 → 08:00-09:30 local = 07:00-08:30 UTC.
    created = client.post(
        f"{API}/courses",
        json={
            "title": "Algorithmique",
            "weekday": 0,
            "start_time": "08:00:00",
            "end_time": "09:30:00",
        },
    )
    assert created.status_code == 201

    clash = client.post(
        f"{API}/events",
        json=event("Réunion", "2030-03-04T08:00:00Z", "2030-03-04T09:00:00Z"),
    )
    assert clash.status_code == 409
    assert clash.json()["conflicts"][0]["kind"] == "course"

    # 09:00Z = 10:00 local : le cours est fini.
    assert (
        client.post(
            f"{API}/events",
            json=event("Réunion", "2030-03-04T09:00:00Z", "2030-03-04T10:00:00Z"),
        ).status_code
        == 201
    )


# ----- rappels ----------------------------------------------------------
def _reminders(db):
    return list(db.scalars(select(EventReminder).order_by(EventReminder.offset_minutes)))


def test_reminders_are_created_updated_and_cleared(client, db_session):
    start = datetime.now(timezone.utc) + timedelta(days=3)
    created = client.post(
        f"{API}/events",
        json=event(
            "Examen",
            start.isoformat(),
            (start + timedelta(hours=2)).isoformat(),
            reminder_offsets=[60, 1440, 60],
        ),
    ).json()
    assert created["reminder_offsets"] == [1440, 60]
    assert [r.offset_minutes for r in _reminders(db_session)] == [60, 1440]

    # Changer seulement le titre ne recrée rien.
    ids = {r.id for r in _reminders(db_session)}
    client.put(f"{API}/events/{created['id']}", json={"title": "Examen final"})
    assert {r.id for r in _reminders(db_session)} == ids

    # Déplacer l'événement recrée des rappels à la nouvelle heure.
    later = start + timedelta(days=1)
    client.put(
        f"{API}/events/{created['id']}",
        json={
            "starts_at": later.isoformat(),
            "ends_at": (later + timedelta(hours=2)).isoformat(),
        },
    )
    assert {r.id for r in _reminders(db_session)}.isdisjoint(ids)

    # Annuler supprime les rappels.
    client.put(f"{API}/events/{created['id']}", json={"status": "cancelled"})
    assert _reminders(db_session) == []


def test_reminder_offsets_are_validated(client):
    too_many = event(reminder_offsets=[1, 2, 3, 4, 5, 6])
    assert client.post(f"{API}/events", json=too_many).status_code == 422
    assert (
        client.post(f"{API}/events", json=event(reminder_offsets=[-5])).status_code
        == 422
    )


def test_scheduler_sends_each_due_reminder_exactly_once(client, db_session):
    start = datetime.now(timezone.utc) + timedelta(hours=2)
    client.post(
        f"{API}/events",
        json=event(
            "Examen BD",
            start.isoformat(),
            (start + timedelta(hours=2)).isoformat(),
            location="Salle B12",
            reminder_offsets=[60],
        ),
    )
    assert len(_reminders(db_session)) == 1

    # Rien n'est dû maintenant.
    assert reminder_service.run_once(TestSession) == 0

    # 55 minutes avant le début : le rappel « 60 min » est échu.
    due_at = start - timedelta(minutes=55)
    assert reminder_service.run_once(TestSession, now=due_at) == 1
    assert reminder_service.run_once(TestSession, now=due_at) == 0

    notifications = list(db_session.scalars(select(Notification)))
    assert len(notifications) == 1
    note = notifications[0]
    assert note.notification_type == "exam"
    assert "Examen BD" in note.title
    assert "Salle B12" in note.body
    assert note.payload["kind"] == "event_reminder"
    assert note.payload["offset_minutes"] == 60


def test_scheduler_skips_cancelled_events(client, db_session):
    start = datetime.now(timezone.utc) + timedelta(hours=2)
    created = client.post(
        f"{API}/events",
        json=event("Exam", start.isoformat(), None, reminder_offsets=[30]),
    ).json()
    # Annulation « sauvage » en base : le planificateur doit quand même s'abstenir.
    row = db_session.get(StudyEvent, UUID(created["id"]))
    row.status = "cancelled"
    db_session.commit()
    assert reminder_service.run_once(TestSession, now=start - timedelta(minutes=20)) == 0
    assert list(db_session.scalars(select(Notification))) == []


def test_reminder_wording():
    assert reminder_service.describe_offset(0) == "maintenant"
    assert reminder_service.describe_offset(1440) == "demain"
    assert reminder_service.describe_offset(2880) == "dans 2 jours"
    assert reminder_service.describe_offset(120) == "dans 2 h"
    assert reminder_service.describe_offset(15) == "dans 15 min"


# ----- calendrier unifié ------------------------------------------------
def test_unified_calendar_merges_events_courses_and_tasks(client):
    client.post(f"{API}/events", json=event())
    client.post(
        f"{API}/courses",
        json={
            "title": "Réseaux",
            "weekday": 0,
            "start_time": "14:00:00",
            "end_time": "15:30:00",
        },
    )
    client.post(
        f"{API}/tasks",
        json={"title": "Rapport TP", "deadline": "2030-03-06T18:00:00Z"},
    )

    response = client.get(
        f"{API}/calendar",
        params={"from": "2030-03-04T00:00:00Z", "to": "2030-03-11T00:00:00Z"},
    )
    assert response.status_code == 200
    items = response.json()
    kinds = [item["kind"] for item in items]
    assert kinds.count("event") == 1
    assert kinds.count("task") == 1
    # Lundi 4 et lundi 11 (exclu : borne haute) → une seule occurrence du cours.
    assert kinds.count("course") == 1
    assert [item["starts_at"] for item in items] == sorted(
        item["starts_at"] for item in items
    )

    only_events = client.get(
        f"{API}/calendar",
        params={
            "from": "2030-03-04T00:00:00Z",
            "to": "2030-03-11T00:00:00Z",
            "include_courses": False,
            "include_tasks": False,
        },
    ).json()
    assert [item["kind"] for item in only_events] == ["event"]


def test_calendar_range_is_validated(client):
    too_long = client.get(
        f"{API}/calendar",
        params={"from": "2030-01-01T00:00:00Z", "to": "2030-06-01T00:00:00Z"},
    )
    assert too_long.status_code == 422
    inverted = client.get(
        f"{API}/calendar",
        params={"from": "2030-03-02T00:00:00Z", "to": "2030-03-01T00:00:00Z"},
    )
    assert inverted.status_code == 422


def test_calendar_is_isolated_per_user(client):
    from app.api.deps import get_current_uid

    client.post(f"{API}/events", json=event("Privé"))
    app.dependency_overrides[get_current_uid] = lambda: "firebase-user-b"
    response = client.get(
        f"{API}/calendar",
        params={"from": "2030-03-04T00:00:00Z", "to": "2030-03-05T00:00:00Z"},
    )
    assert response.json() == []


# ----- IA : événement en langage naturel --------------------------------
class FakeProvider:
    def __init__(self, replies):
        self.replies = list(replies)
        self.calls = []

    def complete(self, messages, json_mode=False):
        self.calls.append(messages)
        reply = self.replies.pop(0)
        if isinstance(reply, Exception):
            raise reply
        return reply


def test_ai_event_parsing_requires_consent_and_returns_draft(client):
    reply = json.dumps(
        {
            "title": "Examen de BD",
            "event_type": "exam",
            "starts_at": "2030-03-04T14:00:00",
            "ends_at": None,
            "location": "Salle B12",
            "description": None,
        }
    )
    provider = FakeProvider([reply])
    app.dependency_overrides[get_llm_provider] = lambda: provider

    denied = client.post(
        f"{API}/ai/events/parse",
        json={"text": "examen de BD lundi 14h salle B12", "timezone": "Africa/Tunis"},
    )
    assert denied.status_code == 403

    client.put(f"{API}/ai/consent", json={"granted": True})
    response = client.post(
        f"{API}/ai/events/parse",
        json={"text": "examen de BD lundi 14h salle B12", "timezone": "Africa/Tunis"},
    )
    assert response.status_code == 200
    draft = response.json()
    assert draft["title"] == "Examen de BD"
    assert draft["event_type"] == "exam"
    assert draft["location"] == "Salle B12"
    # 14:00 à Tunis (UTC+1) = 13:00 UTC.
    assert draft["starts_at"].startswith("2030-03-04T13:00:00")
    assert draft["ai_generated"] is True
    # Le brouillon n'est jamais enregistré.
    assert client.get(f"{API}/events").json() == []


def test_ai_event_parsing_uses_device_utc_offset(client):
    reply = json.dumps(
        {"title": "TP", "event_type": "class", "starts_at": "2030-03-04T14:00:00"}
    )
    app.dependency_overrides[get_llm_provider] = lambda: FakeProvider([reply])
    client.put(f"{API}/ai/consent", json={"granted": True})
    draft = client.post(
        f"{API}/ai/events/parse",
        json={"text": "TP lundi 14h", "utc_offset_minutes": 60},
    ).json()
    assert draft["starts_at"].startswith("2030-03-04T13:00:00")


def test_ai_event_parsing_retries_then_fails_cleanly(client):
    provider = FakeProvider(["pas du json", "toujours pas"])
    app.dependency_overrides[get_llm_provider] = lambda: provider
    client.put(f"{API}/ai/consent", json={"granted": True})
    response = client.post(f"{API}/ai/events/parse", json={"text": "blablabla"})
    assert response.status_code == 503
    assert len(provider.calls) == 2


def test_ai_event_parsing_does_not_retry_provider_failures(client):
    provider = FakeProvider([LLMError("HTTPStatusError"), "inutile"])
    app.dependency_overrides[get_llm_provider] = lambda: provider
    client.put(f"{API}/ai/consent", json={"granted": True})
    response = client.post(f"{API}/ai/events/parse", json={"text": "examen lundi 14h"})
    assert response.status_code == 503
    assert "n’a pas répondu" in response.json()["detail"]
    assert len(provider.calls) == 1


@pytest.mark.parametrize(
    ("status", "expected"),
    [(401, "LLM_API_KEY"), (404, "LLM_MODEL"), (429, "Quota")],
)
def test_ai_event_parsing_explains_provider_http_errors(client, status, expected):
    from types import SimpleNamespace

    failure = LLMError("HTTPStatusError")
    cause = Exception("http")
    cause.response = SimpleNamespace(status_code=status)
    failure.__cause__ = cause
    app.dependency_overrides[get_llm_provider] = lambda: FakeProvider([failure])
    client.put(f"{API}/ai/consent", json={"granted": True})
    response = client.post(f"{API}/ai/events/parse", json={"text": "examen lundi 14h"})
    assert response.status_code == 503
    assert expected in response.json()["detail"]


def test_ai_event_parsing_redacts_contact_details(client):
    reply = json.dumps(
        {"title": "RDV", "event_type": "personal", "starts_at": "2030-03-04T09:00:00"}
    )
    provider = FakeProvider([reply])
    app.dependency_overrides[get_llm_provider] = lambda: provider
    client.put(f"{API}/ai/consent", json={"granted": True})
    client.post(
        f"{API}/ai/events/parse",
        json={"text": "rdv demain, écris à prof@esprit.tn ou appelle +216 20 123 456"},
    )
    sent = json.dumps(provider.calls[0], ensure_ascii=False)
    assert "prof@esprit.tn" not in sent
    assert "20 123 456" not in sent


# ----- lieux (Photon / Geoapify / Google) -------------------------------
def _use_places(monkeypatch, provider, **keys):
    from pydantic import SecretStr

    from app.core.config import get_settings

    settings = get_settings()
    monkeypatch.setattr(settings, "places_provider", provider)
    for name, value in keys.items():
        monkeypatch.setattr(settings, name, SecretStr(value) if value else None)


def _fake_http(monkeypatch, payload_for):
    seen = {}

    def fake_request(method, url, timeout=None, **kwargs):
        seen[url] = (method, kwargs)
        return httpx.Response(
            200, json=payload_for(url), request=httpx.Request(method, url)
        )

    monkeypatch.setattr(places_service.httpx, "request", fake_request)
    return seen


def test_places_photon_needs_no_key_and_returns_coordinates(client, monkeypatch):
    _use_places(monkeypatch, "photon")
    payload = {
        "features": [
            {
                "geometry": {"type": "Point", "coordinates": [10.1932, 36.8995]},
                "properties": {
                    "osm_id": 123,
                    "osm_type": "W",
                    "name": "ESPRIT",
                    "street": "Rue Ibn Khaldoun",
                    "city": "Ariana",
                    "country": "Tunisie",
                },
            },
            {"geometry": {"coordinates": [1, 2]}, "properties": {"osm_id": 9}},
        ]
    }
    seen = _fake_http(monkeypatch, lambda url: payload)

    response = client.get(f"{API}/places/autocomplete", params={"q": "esprit"})
    assert response.status_code == 200
    [suggestion] = response.json()
    assert suggestion["name"] == "ESPRIT"
    assert suggestion["place_id"] == "W123"
    assert suggestion["latitude"] == 36.8995 and suggestion["longitude"] == 10.1932
    assert "Ariana" in suggestion["address"]
    params = seen[places_service.PHOTON_URL][1]["params"]
    assert params["q"] == "esprit" and params["lang"] == "fr"
    assert "StudyMate" in seen[places_service.PHOTON_URL][1]["headers"]["User-Agent"]


def test_places_geoapify_requires_key_then_maps_results(client, monkeypatch):
    _use_places(monkeypatch, "geoapify", geoapify_api_key=None)
    assert client.get(f"{API}/places/autocomplete", params={"q": "abc"}).status_code == 503

    _use_places(monkeypatch, "geoapify", geoapify_api_key="geo-key")
    payload = {
        "features": [
            {
                "properties": {
                    "name": "ESPRIT",
                    "address_line2": "Ariana, Tunisie",
                    "lat": 36.9,
                    "lon": 10.19,
                    "place_id": "abc123",
                }
            }
        ]
    }
    seen = _fake_http(monkeypatch, lambda url: payload)
    [suggestion] = client.get(f"{API}/places/autocomplete", params={"q": "esprit"}).json()
    assert suggestion == {
        "place_id": "abc123",
        "name": "ESPRIT",
        "address": "Ariana, Tunisie",
        "latitude": 36.9,
        "longitude": 10.19,
    }
    assert seen[places_service.GEOAPIFY_URL][1]["params"]["apiKey"] == "geo-key"


def test_places_google_requires_key_and_supports_details(client, monkeypatch):
    _use_places(monkeypatch, "google", google_maps_api_key=None)
    response = client.get(f"{API}/places/autocomplete", params={"q": "ESPRIT"})
    assert response.status_code == 503
    assert response.json()["code"] == "places_unavailable"

    _use_places(monkeypatch, "google", google_maps_api_key="test-key")

    def payload_for(url):
        if url.endswith(":autocomplete"):
            return {
                "suggestions": [
                    {
                        "placePrediction": {
                            "placeId": "ChIJabcdefghij123",
                            "text": {"text": "ESPRIT, Ariana, Tunisie"},
                            "structuredFormat": {
                                "mainText": {"text": "ESPRIT"},
                                "secondaryText": {"text": "Ariana, Tunisie"},
                            },
                        }
                    },
                    {"queryPrediction": {"text": {"text": "ignoré"}}},
                ]
            }
        return {
            "id": "ChIJabcdefghij123",
            "displayName": {"text": "ESPRIT"},
            "formattedAddress": "Ariana, Tunisie",
            "location": {"latitude": 36.89, "longitude": 10.19},
        }

    seen = _fake_http(monkeypatch, payload_for)
    [suggestion] = client.get(f"{API}/places/autocomplete", params={"q": "espr"}).json()
    assert suggestion["place_id"] == "ChIJabcdefghij123"
    assert seen[places_service.GOOGLE_AUTOCOMPLETE_URL][1]["headers"]["X-Goog-Api-Key"] == "test-key"

    details = client.get(
        f"{API}/places/details", params={"place_id": "ChIJabcdefghij123"}
    ).json()
    assert details["latitude"] == 36.89 and details["longitude"] == 10.19
    bad = client.get(f"{API}/places/details", params={"place_id": "../../etc/passwd"})
    assert bad.status_code == 503


def test_places_provider_failure_is_reported_cleanly(client, monkeypatch):
    _use_places(monkeypatch, "photon")

    def boom(method, url, timeout=None, **kwargs):
        raise httpx.ConnectError("down")

    monkeypatch.setattr(places_service.httpx, "request", boom)
    response = client.get(f"{API}/places/autocomplete", params={"q": "esprit"})
    assert response.status_code == 503
    assert response.json()["code"] == "places_unavailable"


def test_places_require_authentication(client):
    from app.api.deps import get_current_uid

    app.dependency_overrides.pop(get_current_uid)
    assert client.get(f"{API}/places/autocomplete", params={"q": "abc"}).status_code == 401
    assert (
        client.get(
            f"{API}/calendar",
            params={"from": "2030-03-04T00:00:00Z", "to": "2030-03-05T00:00:00Z"},
        ).status_code
        == 401
    )


# ----- centre de notifications ------------------------------------------
def test_notification_centre_endpoints(client, db_session):
    from app.models.user import User

    db_session.add(User(firebase_uid="firebase-user-a"))
    db_session.add_all(
        [
            Notification(owner_uid="firebase-user-a", notification_type="exam", title="A", body="a"),
            Notification(owner_uid="firebase-user-a", notification_type="reminder", title="B", body="b"),
            Notification(owner_uid="firebase-user-a", notification_type="reminder", title="C", body="c"),
        ]
    )
    db_session.commit()

    assert client.get(f"{API}/notifications/unread-count").json() == {"count": 3}
    only_exam = client.get(f"{API}/notifications", params={"type": "exam"}).json()
    assert [n["title"] for n in only_exam] == ["A"]

    first = client.get(f"{API}/notifications").json()[0]
    client.put(f"{API}/notifications/{first['id']}/read")
    assert client.get(f"{API}/notifications/unread-count").json() == {"count": 2}
    unread = client.get(f"{API}/notifications", params={"unread_only": True}).json()
    assert len(unread) == 2

    assert client.put(f"{API}/notifications/read-all").json() == {"updated": 2}
    assert client.get(f"{API}/notifications/unread-count").json() == {"count": 0}

    assert client.delete(f"{API}/notifications/{first['id']}").status_code == 204
    assert client.delete(f"{API}/notifications/{first['id']}").status_code == 404
    assert len(client.get(f"{API}/notifications").json()) == 2


def test_http_client_logs_never_expose_api_keys_in_urls():
    import logging

    from app.core.logging import configure_logging

    configure_logging("INFO")
    assert logging.getLogger("httpx").getEffectiveLevel() >= logging.WARNING
    assert logging.getLogger("httpcore").getEffectiveLevel() >= logging.WARNING
