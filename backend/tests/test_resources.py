from app.models.user import User
from app.api.deps import get_current_uid
from app.main import app


def test_task_crud_is_scoped_to_authenticated_firebase_uid(client, db_session):
    response = client.post(
        "/api/v1/tasks",
        json={"title": "Réviser les fractions", "priority": "high"},
    )
    assert response.status_code == 201
    task = response.json()

    assert task["title"] == "Réviser les fractions"
    assert task["is_completed"] is False

    response = client.patch(
        f"/api/v1/tasks/{task['id']}",
        json={"is_completed": True},
    )
    assert response.status_code == 200
    assert response.json()["is_completed"] is True

    db_session.add(User(firebase_uid="firebase-user-b"))
    db_session.commit()
    from app.models.task import StudyTask

    other_user_task = StudyTask(owner_uid="firebase-user-b", title="Privé", priority="low")
    db_session.add(other_user_task)
    db_session.commit()

    response = client.get("/api/v1/tasks")
    assert response.status_code == 200
    assert [item["title"] for item in response.json()] == ["Réviser les fractions"]

    response = client.get(f"/api/v1/tasks/{other_user_task.id}")
    assert response.status_code == 404


def test_course_task_and_note_are_owned_and_linked(client):
    course_response = client.post(
        "/api/v1/courses",
        json={"title": "Biologie", "code": "BIO-101"},
    )
    assert course_response.status_code == 201
    course_id = course_response.json()["id"]

    task_response = client.post(
        "/api/v1/tasks",
        json={"title": "Lire le chapitre", "course_id": course_id},
    )
    assert task_response.status_code == 201
    assert task_response.json()["course_id"] == course_id

    note_response = client.post(
        "/api/v1/notes",
        json={
            "title": "Résumé du cours",
            "content": "La cellule est l’unité fondamentale du vivant.",
            "course_id": course_id,
        },
    )
    assert note_response.status_code == 201

    assert client.get("/api/v1/courses").json()[0]["title"] == "Biologie"
    assert client.get("/api/v1/notes").json()[0]["course_id"] == course_id


def test_course_link_cannot_be_forged_for_another_owner(client, db_session):
    db_session.add(User(firebase_uid="firebase-user-b"))
    db_session.commit()
    from app.models.course import Course

    foreign_course = Course(owner_uid="firebase-user-b", title="Private course")
    db_session.add(foreign_course)
    db_session.commit()

    response = client.post(
        "/api/v1/tasks",
        json={"title": "Task", "course_id": str(foreign_course.id)},
    )

    assert response.status_code == 404


def test_private_endpoints_require_a_bearer_token(client):
    app.dependency_overrides.pop(get_current_uid)

    response = client.get("/api/v1/tasks")

    assert response.status_code == 401
