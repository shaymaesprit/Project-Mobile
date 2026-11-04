from datetime import time

from app.models.course import Course
from app.models.user import User


def _scheduled_course(title, weekday, start_time, end_time, **values):
    return {
        "title": title,
        "weekday": weekday,
        "start_time": start_time,
        "end_time": end_time,
        **values,
    }


def test_scheduled_course_crud_and_weekly_schedule(client):
    created = client.post(
        "/api/v1/courses",
        json=_scheduled_course(
            "Biology",
            0,
            "09:00",
            "10:30",
            code="BIO-101",
            professor="Dr. Curie",
            room="B12",
        ),
    )
    assert created.status_code == 201
    course = created.json()
    assert course["weekday"] == 0
    assert course["start_time"] == "09:00:00"
    assert course["end_time"] == "10:30:00"
    course_id = course["id"]

    schedule = client.get("/api/v1/courses/schedule")
    assert schedule.status_code == 200
    assert [item["id"] for item in schedule.json()] == [course_id]

    updated = client.put(
        f"/api/v1/courses/{course_id}",
        json=_scheduled_course(
            "Cell biology",
            2,
            "11:00",
            "12:00",
            professor="Dr. Curie",
            room="C08",
        ),
    )
    assert updated.status_code == 200
    assert updated.json()["title"] == "Cell biology"
    assert updated.json()["weekday"] == 2
    assert client.get("/api/v1/courses/schedule").json()[0]["id"] == course_id

    assert client.get(f"/api/v1/courses/{course_id}").status_code == 200
    assert client.get("/api/v1/courses").status_code == 200
    assert client.delete(f"/api/v1/courses/{course_id}").status_code == 204
    assert client.get("/api/v1/courses").json() == []
    assert client.get("/api/v1/courses/schedule").json() == []


def test_course_schedule_rejects_overlaps_but_allows_adjacent_classes(client):
    first = client.post(
        "/api/v1/courses",
        json=_scheduled_course("Math", 0, "09:00", "10:00"),
    )
    assert first.status_code == 201

    adjacent = client.post(
        "/api/v1/courses",
        json=_scheduled_course("Physics", 0, "10:00", "11:00"),
    )
    assert adjacent.status_code == 201

    overlap = client.post(
        "/api/v1/courses",
        json=_scheduled_course("Chemistry", 0, "09:59", "10:30"),
    )
    assert overlap.status_code == 409
    assert overlap.json()["code"] == "course_schedule_conflict"

    other_day = client.post(
        "/api/v1/courses",
        json=_scheduled_course("Literature", 1, "09:30", "10:30"),
    )
    assert other_day.status_code == 201

    conflicting_update = client.put(
        f"/api/v1/courses/{adjacent.json()['id']}",
        json={"weekday": 0, "start_time": "09:30", "end_time": "10:15"},
    )
    assert conflicting_update.status_code == 409
    assert client.get(f"/api/v1/courses/{adjacent.json()['id']}").json()[
        "start_time"
    ] == "10:00:00"

    updated = client.put(
        f"/api/v1/courses/{first.json()['id']}",
        json={"start_time": "08:00", "end_time": "09:00"},
    )
    assert updated.status_code == 200


def test_course_schedule_validates_complete_ordered_intervals(client):
    assert client.post(
        "/api/v1/courses",
        json={"title": "Missing time", "weekday": 0, "start_time": "09:00"},
    ).status_code == 422
    assert client.post(
        "/api/v1/courses",
        json=_scheduled_course("Invalid day", 7, "09:00", "10:00"),
    ).status_code == 422
    assert client.post(
        "/api/v1/courses",
        json=_scheduled_course("Invalid interval", 0, "10:00", "10:00"),
    ).status_code == 422
def test_courses_and_conflicts_are_private_to_the_owner(client, db_session):
    db_session.add(User(firebase_uid="firebase-user-b"))
    db_session.add(
        Course(
            owner_uid="firebase-user-b",
            title="Another student's class",
            weekday=0,
            start_time=time(9),
            end_time=time(10),
        )
    )
    db_session.commit()
    foreign_course = (
        db_session.query(Course)
        .filter(Course.owner_uid == "firebase-user-b")
        .one()
    )

    own_course = client.post(
        "/api/v1/courses",
        json=_scheduled_course("My class", 0, "09:00", "10:00"),
    )
    assert own_course.status_code == 201
    assert client.get("/api/v1/courses/schedule").json()[0]["title"] == "My class"
    assert client.get(f"/api/v1/courses/{foreign_course.id}").status_code == 404

    from app.api.deps import get_current_uid

    client.app.dependency_overrides[get_current_uid] = lambda: "firebase-user-b"
    assert [
        course["title"] for course in client.get("/api/v1/courses").json()
    ] == ["Another student's class"]
    assert [
        course["title"] for course in client.get("/api/v1/courses/schedule").json()
    ] == ["Another student's class"]
