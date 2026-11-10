import json
from datetime import date, datetime, timedelta, timezone

import pytest

from app.api.dependencies import get_holiday_service, get_knowledge_service
from app.main import app
from app.models.timetable_share import TimetableShare
from app.services.ai_service import get_llm_provider
from app.services.holiday_service import HolidayService
from app.services.knowledge_service import KnowledgeService
from app.services.planning_service import PlanningService

MONDAY = date(2026, 11, 16)
TUESDAY = MONDAY + timedelta(days=1)


@pytest.fixture(autouse=True)
def fake_holidays():
    """Mardi 17/11/2026 est férié ; aucun appel réseau."""
    HolidayService.clear_cache()
    service = HolidayService(
        "TN",
        fetcher=lambda year, country: [
            {"date": TUESDAY.isoformat(), "name": "Test Day", "localName": "Jour test"}
        ],
    )
    app.dependency_overrides[get_holiday_service] = lambda: service
    yield service
    HolidayService.clear_cache()


def _course(client, title, weekday, start, end, **extra):
    response = client.post(
        "/api/v1/courses",
        json={"title": title, "weekday": weekday, "start_time": start, "end_time": end, **extra},
    )
    assert response.status_code == 201, response.text
    return response.json()


# ── Agenda hebdomadaire ────────────────────────────────────────────────────


def test_week_agenda_cancels_courses_on_holidays_and_finds_conflicts(client):
    _course(client, "Algèbre", 0, "09:00:00", "11:00:00")
    _course(client, "Physique", 0, "11:00:00", "13:00:00")
    _course(client, "Chimie", 1, "14:00:00", "16:00:00")  # mardi férié
    # Un événement qui chevauche Algèbre (forcé malgré l'alerte de conflit).
    event = client.post(
        "/api/v1/events?force=true",
        json={
            "title": "Réunion club",
            "event_type": "personal",
            "starts_at": f"{MONDAY}T10:00:00+00:00",
            "ends_at": f"{MONDAY}T10:30:00+00:00",
        },
    )
    assert event.status_code == 201, event.text

    response = client.get(f"/api/v1/schedule/week-agenda?week_start={MONDAY + timedelta(days=2)}")

    assert response.status_code == 200, response.text
    body = response.json()
    assert body["week_start"] == MONDAY.isoformat()  # ramené au lundi
    monday, tuesday = body["days"][0], body["days"][1]
    assert [item["title"] for item in monday["items"]] == ["Algèbre", "Réunion club", "Physique"]
    assert len(monday["conflicts"]) == 1
    assert {c["title"] for c in monday["conflicts"][0]} == {"Algèbre", "Réunion club"}
    assert monday["free_slots"][0]["starts_at"].startswith(f"{MONDAY}T08:00")
    assert tuesday["holiday"]["local_name"] == "Jour test"
    assert tuesday["items"] == []
    assert [item["title"] for item in tuesday["cancelled"]] == ["Chimie"]
    # 4 h de cours effectives (Chimie annulée)
    assert body["stats"]["course_hours"] == 4.0


def test_holiday_api_failure_never_breaks_agenda(client):
    def broken(year, country):
        import httpx

        raise httpx.ConnectError("offline")

    HolidayService.clear_cache()
    app.dependency_overrides[get_holiday_service] = lambda: HolidayService("TN", fetcher=broken)

    response = client.get(f"/api/v1/schedule/week-agenda?week_start={MONDAY}")

    assert response.status_code == 200
    assert all(day["holiday"] is None for day in response.json()["days"])


# ── Score et planification ────────────────────────────────────────────────


def test_score_ranks_urgent_important_tasks_first(client, db_session):
    hard = _course(client, "Maths", 2, "08:00:00", "09:00:00", coefficient=4, difficulte_percue=5)
    now = datetime(2026, 11, 16, 7, 0, tzinfo=timezone.utc)
    client.post("/api/v1/tasks", json={"title": "Lecture libre", "priority": "low"})
    client.post(
        "/api/v1/tasks",
        json={
            "title": "Devoir de maths",
            "priority": "high",
            "deadline": (now + timedelta(hours=30)).isoformat(),
            "course_id": hard["id"],
        },
    )

    db_session.info["firebase_uid"] = "firebase-user-a"
    plan = PlanningService(db_session, HolidayService("TN", fetcher=lambda y, c: [])).plan(
        "firebase-user-a", days=3, now=now
    )

    first, second = plan["items"]
    assert first["title"] == "Devoir de maths"
    assert first["score"] > second["score"]
    assert "Échéance dans moins de 48 h" in first["reasons"]
    assert any("coefficient" in reason for reason in first["reasons"])


def test_plan_places_sessions_in_free_slots_before_deadline(client, db_session):
    _course(client, "Algèbre", 0, "08:00:00", "12:00:00")  # lundi matin occupé
    now = datetime(2026, 11, 16, 7, 0, tzinfo=timezone.utc)
    client.post(
        "/api/v1/tasks",
        json={
            "title": "Exposé",
            "priority": "high",
            "deadline": datetime(2026, 11, 16, 18, 0, tzinfo=timezone.utc).isoformat(),
        },
    )

    db_session.info["firebase_uid"] = "firebase-user-a"
    plan = PlanningService(db_session, HolidayService("TN", fetcher=lambda y, c: [])).plan(
        "firebase-user-a", days=2, now=now
    )

    item = plan["items"][0]
    assert item["status"] == "planned"
    assert item["planned_minutes"] >= item["estimated_minutes"] - 25
    for session in item["sessions"]:
        start = session["starts_at"]
        end = session["ends_at"]
        assert start.hour >= 12  # jamais pendant le cours
        assert end <= datetime(2026, 11, 16, 18, 0, tzinfo=timezone.utc)  # avant l'échéance
        assert session["minutes"] <= 90


def test_plan_reports_overdue_tasks(client, db_session):
    now = datetime(2026, 11, 16, 9, 0, tzinfo=timezone.utc)
    client.post(
        "/api/v1/tasks",
        json={"title": "Rendu oublié", "deadline": (now - timedelta(days=1)).isoformat()},
    )
    db_session.info["firebase_uid"] = "firebase-user-a"
    plan = PlanningService(db_session, HolidayService("TN", fetcher=lambda y, c: [])).plan(
        "firebase-user-a", days=2, now=now
    )
    assert plan["items"][0]["status"] == "overdue"
    assert plan["items"][0]["sessions"]  # calée au plus tôt quand même


def test_plan_endpoint(client):
    client.post("/api/v1/tasks", json={"title": "Réviser", "priority": "medium"})
    response = client.get("/api/v1/tasks/plan?days=5")
    assert response.status_code == 200, response.text
    assert response.json()["items"][0]["title"] == "Réviser"
    assert client.get("/api/v1/tasks/plan?days=99").status_code == 422


# ── Partage par QR code ───────────────────────────────────────────────────


def test_share_link_qr_and_public_read(client, db_session):
    _course(client, "Algèbre", 0, "09:00:00", "11:00:00", room="B12")

    share = client.post("/api/v1/timetable/shares")
    assert share.status_code == 201, share.text
    body = share.json()
    assert body["qr_url"].startswith("https://api.qrserver.com/v1/create-qr-code/")
    assert body["link"].endswith(f"/timetable/shared/{body['token']}/page")
    assert len(client.get("/api/v1/timetable/shares").json()) == 1

    app.dependency_overrides.pop(__import__("app.api.deps", fromlist=["x"]).get_current_uid)
    public = client.get(f"/api/v1/timetable/shared/{body['token']}")
    assert public.status_code == 200, public.text
    assert public.json()["courses"][0]["title"] == "Algèbre"
    assert "email" not in json.dumps(public.json())
    page = client.get(f"/api/v1/timetable/shared/{body['token']}/page")
    assert page.status_code == 200
    assert "text/html" in page.headers["content-type"]
    assert "Algèbre" in page.text and "salle B12" in page.text


def test_share_can_be_revoked_and_expires(client, db_session):
    share = client.post("/api/v1/timetable/shares").json()
    assert client.delete(f"/api/v1/timetable/shares/{share['id']}").status_code == 204
    assert client.get(f"/api/v1/timetable/shared/{share['token']}").status_code == 410

    other = client.post("/api/v1/timetable/shares").json()
    row = db_session.get(TimetableShare, __import__("uuid").UUID(other["id"]))
    row.expires_at = datetime.now(timezone.utc) - timedelta(minutes=1)
    db_session.commit()
    assert client.get(f"/api/v1/timetable/shared/{other['token']}").status_code == 410
    assert client.get("/api/v1/timetable/shared/unknown-token").status_code == 404


def test_cannot_revoke_someone_elses_share(client):
    share = client.post("/api/v1/timetable/shares").json()
    from app.api.deps import get_current_uid

    app.dependency_overrides[get_current_uid] = lambda: "firebase-user-b"
    assert client.delete(f"/api/v1/timetable/shares/{share['id']}").status_code == 404


# ── Décomposition IA ──────────────────────────────────────────────────────


class FakeProvider:
    def __init__(self, replies):
        self.replies = list(replies)

    def complete(self, messages, json_mode=False):
        return self.replies.pop(0)


STEPS = {"steps": [
    {"title": "Relire le cours", "minutes": 30},
    {"title": "Faire les exercices 1 à 5", "minutes": 45},
    {"title": "Corriger et noter les erreurs", "minutes": 20},
]}


def test_breakdown_creates_subtasks(client):
    app.dependency_overrides[get_llm_provider] = lambda: FakeProvider(["oops", json.dumps(STEPS)])
    client.put("/api/v1/ai/consent", json={"granted": True})
    task = client.post("/api/v1/tasks", json={"title": "Préparer le partiel", "priority": "high"}).json()

    response = client.post(f"/api/v1/ai/tasks/{task['id']}/breakdown", json={"create_tasks": True})

    assert response.status_code == 200, response.text
    assert [s["title"] for s in response.json()["steps"]][0] == "Relire le cours"
    assert len(response.json()["created_task_ids"]) == 3
    titles = [t["title"] for t in client.get("/api/v1/tasks").json()]
    assert "1. Relire le cours" in titles


def test_breakdown_requires_consent(client):
    app.dependency_overrides[get_llm_provider] = lambda: FakeProvider([json.dumps(STEPS)])
    task = client.post("/api/v1/tasks", json={"title": "Préparer le partiel"}).json()
    response = client.post(f"/api/v1/ai/tasks/{task['id']}/breakdown")
    assert response.status_code == 403


# ── Wikipédia ─────────────────────────────────────────────────────────────


def test_wikipedia_enrichment(client):
    def getter(url, params):
        if "search" in url:
            return {"pages": [{"title": "Photosynthèse", "description": "processus"}]}
        return {
            "title": "Photosynthèse",
            "extract": "La photosynthèse est le processus…",
            "content_urls": {"desktop": {"page": "https://fr.wikipedia.org/wiki/Photosynth%C3%A8se"}},
        }

    KnowledgeService.clear_cache()
    app.dependency_overrides[get_knowledge_service] = lambda: KnowledgeService(getter)

    response = client.get("/api/v1/knowledge/wikipedia?q=photosynthese")

    assert response.status_code == 200, response.text
    assert response.json()[0]["extract"].startswith("La photosynthèse")
    assert client.get("/api/v1/knowledge/wikipedia?q=a").status_code == 422
