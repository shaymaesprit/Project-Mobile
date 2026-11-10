"""Tests for the /api/v1/timetable CRUD endpoints."""

from app.models.course import Course
from app.models.user import User


def _make_course(client, title="Mathématiques", weekday=None):
    payload = {"title": title}
    if weekday is not None:
        payload.update({"weekday": weekday, "start_time": "00:00", "end_time": "23:59"})
    resp = client.post("/api/v1/courses", json=payload)
    assert resp.status_code == 201
    return resp.json()["id"]


def _entry_payload(course_id, jour=0, start="09:00", end="10:00", type_seance="COURS"):
    return {
        "course_id": course_id,
        "jour": jour,
        "heure_debut": start,
        "heure_fin": end,
        "type_seance": type_seance,
    }


# ── CRUD basics ───────────────────────────────────────────────────────────────

def test_create_timetable_entry(client):
    cid = _make_course(client)
    resp = client.post("/api/v1/timetable", json=_entry_payload(cid))
    assert resp.status_code == 201
    data = resp.json()
    assert data["course_id"] == cid
    assert data["jour"] == 0
    assert data["heure_debut"] == "09:00:00"
    assert data["heure_fin"] == "10:00:00"
    assert data["type_seance"] == "COURS"


def test_list_timetable_entries(client):
    cid = _make_course(client)
    client.post("/api/v1/timetable", json=_entry_payload(cid, jour=0))
    client.post("/api/v1/timetable", json=_entry_payload(cid, jour=1, start="11:00", end="12:00"))
    resp = client.get("/api/v1/timetable")
    assert resp.status_code == 200
    assert len(resp.json()) == 2


def test_filter_by_day(client):
    cid = _make_course(client)
    client.post("/api/v1/timetable", json=_entry_payload(cid, jour=0))
    client.post("/api/v1/timetable", json=_entry_payload(cid, jour=1, start="11:00", end="12:00"))
    resp = client.get("/api/v1/timetable?jour=0")
    assert resp.status_code == 200
    assert len(resp.json()) == 1
    assert resp.json()[0]["jour"] == 0


def test_filter_by_course(client):
    cid1 = _make_course(client, "Physique")
    cid2 = _make_course(client, "Chimie")
    client.post("/api/v1/timetable", json=_entry_payload(cid1, jour=0))
    client.post("/api/v1/timetable", json=_entry_payload(cid2, jour=1, start="11:00", end="12:00"))
    resp = client.get(f"/api/v1/timetable?course_id={cid1}")
    assert resp.status_code == 200
    assert len(resp.json()) == 1
    assert resp.json()[0]["course_id"] == cid1


def test_get_single_entry(client):
    cid = _make_course(client)
    created = client.post("/api/v1/timetable", json=_entry_payload(cid)).json()
    resp = client.get(f"/api/v1/timetable/{created['id']}")
    assert resp.status_code == 200
    assert resp.json()["id"] == created["id"]


def test_update_entry(client):
    cid = _make_course(client)
    created = client.post("/api/v1/timetable", json=_entry_payload(cid)).json()
    resp = client.put(
        f"/api/v1/timetable/{created['id']}",
        json={"salle": "B204", "type_seance": "TD"},
    )
    assert resp.status_code == 200
    assert resp.json()["salle"] == "B204"
    assert resp.json()["type_seance"] == "TD"


def test_delete_entry(client):
    cid = _make_course(client)
    created = client.post("/api/v1/timetable", json=_entry_payload(cid)).json()
    assert client.delete(f"/api/v1/timetable/{created['id']}").status_code == 204
    assert client.get(f"/api/v1/timetable/{created['id']}").status_code == 404


# ── Validation ────────────────────────────────────────────────────────────────

def test_invalid_time_range(client):
    cid = _make_course(client)
    resp = client.post(
        "/api/v1/timetable",
        json=_entry_payload(cid, start="10:00", end="09:00"),
    )
    assert resp.status_code == 422


def test_equal_times_rejected(client):
    cid = _make_course(client)
    resp = client.post(
        "/api/v1/timetable",
        json=_entry_payload(cid, start="09:00", end="09:00"),
    )
    assert resp.status_code == 422


def test_invalid_jour(client):
    cid = _make_course(client)
    resp = client.post(
        "/api/v1/timetable",
        json=_entry_payload(cid, jour=7),
    )
    assert resp.status_code == 422


def test_overlapping_entries_rejected(client):
    cid = _make_course(client)
    client.post("/api/v1/timetable", json=_entry_payload(cid, start="09:00", end="10:00"))
    resp = client.post(
        "/api/v1/timetable",
        json=_entry_payload(cid, start="09:30", end="10:30"),
    )
    assert resp.status_code == 409
    assert resp.json()["code"] == "course_schedule_conflict"


def test_adjacent_entries_allowed(client):
    cid = _make_course(client)
    client.post("/api/v1/timetable", json=_entry_payload(cid, start="08:00", end="09:00"))
    resp = client.post(
        "/api/v1/timetable",
        json=_entry_payload(cid, start="09:00", end="10:00"),
    )
    assert resp.status_code == 201


def test_overlap_on_different_days_allowed(client):
    cid = _make_course(client)
    client.post("/api/v1/timetable", json=_entry_payload(cid, jour=0, start="09:00", end="10:00"))
    resp = client.post(
        "/api/v1/timetable",
        json=_entry_payload(cid, jour=1, start="09:00", end="10:00"),
    )
    assert resp.status_code == 201


def test_invalid_course_reference(client):
    import uuid
    resp = client.post(
        "/api/v1/timetable",
        json=_entry_payload(str(uuid.uuid4())),
    )
    assert resp.status_code == 404


def test_course_must_belong_to_user(client, db_session):
    other_user = User(firebase_uid="other-user-x")
    other_course = Course(owner_uid="other-user-x", title="Foreign Course")
    db_session.add(other_user)
    db_session.add(other_course)
    db_session.commit()
    resp = client.post(
        "/api/v1/timetable",
        json=_entry_payload(str(other_course.id)),
    )
    assert resp.status_code == 404


# ── User isolation ────────────────────────────────────────────────────────────

def test_user_cannot_read_another_users_entry(client, db_session):
    from app.api.deps import get_current_uid
    from app.main import app as fastapi_app

    cid = _make_course(client)
    entry = client.post("/api/v1/timetable", json=_entry_payload(cid)).json()

    fastapi_app.dependency_overrides[get_current_uid] = lambda: "attacker-uid"
    resp = client.get(f"/api/v1/timetable/{entry['id']}")
    assert resp.status_code == 404
    fastapi_app.dependency_overrides[get_current_uid] = lambda: "firebase-user-a"


def test_user_cannot_delete_another_users_entry(client, db_session):
    from app.api.deps import get_current_uid
    from app.main import app as fastapi_app

    cid = _make_course(client)
    entry = client.post("/api/v1/timetable", json=_entry_payload(cid)).json()

    fastapi_app.dependency_overrides[get_current_uid] = lambda: "attacker-uid"
    resp = client.delete(f"/api/v1/timetable/{entry['id']}")
    assert resp.status_code == 404
    fastapi_app.dependency_overrides[get_current_uid] = lambda: "firebase-user-a"
