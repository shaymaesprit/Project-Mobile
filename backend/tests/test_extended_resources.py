from uuid import uuid4

from app.api.deps import get_current_uid
from app.main import app
from app.models.course import Course
from app.models.extended import Flashcard, FlashcardDeck, Notification
from app.models.user import User


def test_user_and_learning_profile_endpoints(client, db_session, monkeypatch):
    response = client.get("/api/v1/users/me")
    assert response.status_code == 200
    assert response.json()["firebase_uid"] == "firebase-user-a"

    response = client.put(
        "/api/v1/users/me",
        json={"display_name": "  Amina  ", "locale": "fr-FR"},
    )
    assert response.status_code == 200
    assert response.json()["display_name"] == "Amina"
    assert response.json()["locale"] == "fr-FR"

    response = client.get("/api/v1/profile")
    assert response.status_code == 200
    assert response.json()["daily_study_goal_minutes"] == 60

    response = client.put(
        "/api/v1/profile",
        json={
            "preferred_learning_style": "visual",
            "daily_study_goal_minutes": 45,
            "preferences": {"break_minutes": 5},
        },
    )
    assert response.status_code == 200
    assert response.json()["daily_study_goal_minutes"] == 45
    assert response.json()["preferences"] == {"break_minutes": 5}

    response = client.put(
        "/api/v1/profile",
        json={
            "study_level": "  Licence  ",
            "specialty": "  Informatique  ",
            "academic_goals": ["  Réussir les examens  ", "Stage de fin d'études"],
            "preferred_learning_style": "visual",
        },
    )
    assert response.status_code == 200
    assert response.json()["study_level"] == "Licence"
    assert response.json()["specialty"] == "Informatique"
    assert response.json()["academic_goals"] == [
        "Réussir les examens",
        "Stage de fin d'études",
    ]

    assert client.put(
        "/api/v1/profile",
        json={"academic_goals": [""]},
    ).status_code == 422
    assert client.put(
        "/api/v1/profile",
        json={"academic_goals": ["Objectif"] * 21},
    ).status_code == 422

    calls = []
    monkeypatch.setattr(
        "app.api.routes.users.delete_firebase_account",
        lambda uid: calls.append(uid),
    )
    response = client.delete("/api/v1/users/me")
    assert response.status_code == 204
    assert calls == ["firebase-user-a"]
    assert db_session.get(User, "firebase-user-a") is None


def test_first_authenticated_request_creates_profile_from_verified_token(
    client, db_session, monkeypatch
):
    from app.api import deps

    client.app.dependency_overrides.pop(deps.get_current_uid)
    monkeypatch.setattr(deps, "_firebase_app", lambda: None)
    monkeypatch.setattr(
        deps.firebase_auth,
        "verify_id_token",
        lambda token, **kwargs: {
            "uid": "verified-firebase-user",
            "email": "student@example.com",
            "name": "Student",
            "picture": "https://example.com/avatar.png",
        },
    )

    response = client.get(
        "/api/v1/users/me",
        headers={"Authorization": "Bearer verified-token"},
    )

    assert response.status_code == 200
    assert response.json()["firebase_uid"] == "verified-firebase-user"
    assert response.json()["email"] == "student@example.com"
    assert response.json()["display_name"] == "Student"
    assert response.json()["photo_url"] == "https://example.com/avatar.png"
    assert db_session.get(User, "firebase-user-a") is None


def test_course_task_and_note_put_crud(client):
    course = client.post(
        "/api/v1/courses",
        json={"title": "Biology", "color": "#112233"},
    )
    assert course.status_code == 201
    course_id = course.json()["id"]

    response = client.put(
        f"/api/v1/courses/{course_id}",
        json={"title": "Cell biology"},
    )
    assert response.status_code == 200
    assert response.json()["title"] == "Cell biology"

    task = client.post(
        "/api/v1/tasks",
        json={"title": "Read chapter", "course_id": course_id},
    )
    assert task.status_code == 201
    task_id = task.json()["id"]

    response = client.put(
        f"/api/v1/tasks/{task_id}",
        json={"is_completed": True},
    )
    assert response.status_code == 200
    assert response.json()["completed_at"] is not None
    assert client.get(f"/api/v1/tasks/{task_id}").status_code == 200

    note = client.post(
        "/api/v1/notes",
        json={"title": "Summary", "content": "Important", "course_id": course_id},
    )
    assert note.status_code == 201
    note_id = note.json()["id"]

    response = client.put(
        f"/api/v1/notes/{note_id}",
        json={"content": "Updated"},
    )
    assert response.status_code == 200
    assert response.json()["content"] == "Updated"

    assert client.delete(f"/api/v1/notes/{note_id}").status_code == 204
    assert client.delete(f"/api/v1/tasks/{task_id}").status_code == 204
    assert client.delete(f"/api/v1/courses/{course_id}").status_code == 204


def test_flashcard_crud_and_course_ownership(client, db_session):
    foreign_owner = User(firebase_uid="firebase-user-b")
    foreign_course = Course(owner_uid=foreign_owner.firebase_uid, title="Private")
    db_session.add_all([foreign_owner, foreign_course])
    db_session.commit()

    response = client.post(
        "/api/v1/flashcards",
        json={
            "question": "  What is SQL? ",
            "answer": "A query language",
            "course_id": str(foreign_course.id),
        },
    )
    assert response.status_code == 404

    response = client.post(
        "/api/v1/flashcards",
        json={"question": "What is SQL?", "answer": "A query language"},
    )
    assert response.status_code == 201
    card_id = response.json()["id"]
    assert response.json()["question"] == "What is SQL?"

    assert client.get("/api/v1/flashcards").status_code == 200
    assert client.get(f"/api/v1/flashcards/{card_id}").status_code == 200
    response = client.put(
        f"/api/v1/flashcards/{card_id}",
        json={"repetitions": 2, "interval_days": 3},
    )
    assert response.status_code == 200
    assert response.json()["repetitions"] == 2
    assert client.delete(f"/api/v1/flashcards/{card_id}").status_code == 204

    foreign_card = Flashcard(
        owner_uid="firebase-user-b",
        question="Private",
        answer="Only for another account",
    )
    db_session.add(foreign_card)
    db_session.commit()
    assert client.get(f"/api/v1/flashcards/{foreign_card.id}").status_code == 404


def test_flashcard_deck_crud_review_and_progress(client, db_session):
    course = client.post(
        "/api/v1/courses",
        json={"title": "Biology"},
    )
    assert course.status_code == 201

    deck = client.post(
        "/api/v1/flashcard-decks",
        json={
            "title": "  Cell structures ",
            "description": "Review organelles",
            "course_id": course.json()["id"],
        },
    )
    assert deck.status_code == 201
    deck_id = deck.json()["id"]
    assert deck.json()["title"] == "Cell structures"
    assert deck.json()["source"] == "manual"

    response = client.post(
        f"/api/v1/flashcard-decks/{deck_id}/cards",
        json={"question": "What is a mitochondrion?", "answer": "An organelle"},
    )
    assert response.status_code == 201
    card_id = response.json()["id"]
    assert response.json()["deck_id"] == deck_id
    assert response.json()["course_id"] == course.json()["id"]

    response = client.put(
        f"/api/v1/flashcards/{card_id}",
        json={"answer": "An energy-producing organelle"},
    )
    assert response.status_code == 200
    assert response.json()["answer"] == "An energy-producing organelle"

    response = client.post(
        f"/api/v1/flashcards/{card_id}/review",
        json={"is_correct": True},
    )
    assert response.status_code == 200
    assert response.json()["total_reviews"] == 1
    assert response.json()["correct_answers"] == 1
    assert response.json()["flashcard"]["repetitions"] == 1

    response = client.post(
        f"/api/v1/flashcards/{card_id}/review",
        json={"is_correct": False},
    )
    assert response.status_code == 200
    assert response.json()["incorrect_answers"] == 1
    assert response.json()["flashcard"]["repetitions"] == 0

    progress = client.get(f"/api/v1/flashcard-decks/{deck_id}/progress")
    assert progress.status_code == 200
    assert progress.json()["total_cards"] == 1
    assert progress.json()["reviewed_cards"] == 1
    assert progress.json()["total_reviews"] == 2
    assert progress.json()["accuracy_rate"] == 50

    response = client.put(
        f"/api/v1/flashcard-decks/{deck_id}",
        json={"title": "Cell biology"},
    )
    assert response.status_code == 200
    assert response.json()["title"] == "Cell biology"
    assert client.get(f"/api/v1/flashcard-decks/{deck_id}/cards").status_code == 200
    assert client.delete(f"/api/v1/flashcards/{card_id}").status_code == 204
    assert client.delete(f"/api/v1/flashcard-decks/{deck_id}").status_code == 204


def test_flashcard_deck_and_review_are_owner_scoped(client, db_session):
    foreign_owner = User(firebase_uid="firebase-user-b")
    foreign_deck = FlashcardDeck(
        owner_uid=foreign_owner.firebase_uid,
        title="Private deck",
    )
    db_session.add_all([foreign_owner, foreign_deck])
    db_session.flush()
    foreign_card = Flashcard(
        owner_uid=foreign_owner.firebase_uid,
        deck_id=foreign_deck.id,
        question="Private",
        answer="Only for another account",
    )
    db_session.add(foreign_card)
    db_session.commit()

    assert client.get(f"/api/v1/flashcard-decks/{foreign_deck.id}").status_code == 404
    assert (
        client.get(f"/api/v1/flashcard-decks/{foreign_deck.id}/cards").status_code
        == 404
    )
    assert (
        client.post(
            f"/api/v1/flashcards/{foreign_card.id}/review",
            json={"is_correct": True},
        ).status_code
        == 404
    )


def test_evaluation_crud_and_grade_validation(client):
    invalid = client.post(
        "/api/v1/evaluations",
        json={"title": "Exam", "score": 11, "max_score": 10},
    )
    assert invalid.status_code == 422
    assert (
        client.post(
            "/api/v1/evaluations",
            json={"title": "Missing maximum", "score": 8},
        ).status_code
        == 422
    )

    response = client.post(
        "/api/v1/evaluations",
        json={"title": "  Midterm ", "score": 7, "max_score": 10},
    )
    assert response.status_code == 201
    evaluation_id = response.json()["id"]
    assert response.json()["title"] == "Midterm"

    response = client.put(
        f"/api/v1/evaluations/{evaluation_id}",
        json={"max_score": 6},
    )
    assert response.status_code == 422
    response = client.put(
        f"/api/v1/evaluations/{evaluation_id}",
        json={"score": 8, "max_score": 12},
    )
    assert response.status_code == 200
    assert client.get(f"/api/v1/evaluations/{evaluation_id}").status_code == 200
    assert client.get("/api/v1/evaluations").status_code == 200
    assert client.delete(f"/api/v1/evaluations/{evaluation_id}").status_code == 204


def test_evaluation_summary_calculates_averages_and_trend(client):
    course = client.post("/api/v1/courses", json={"title": "Mathematics"})
    assert course.status_code == 201
    course_id = course.json()["id"]
    client.post(
        "/api/v1/evaluations",
        json={
            "title": "Quiz 1",
            "course_id": course_id,
            "score": 8,
            "max_score": 10,
            "scheduled_at": "2026-10-01T10:00:00Z",
        },
    )
    client.post(
        "/api/v1/evaluations",
        json={
            "title": "Quiz 2",
            "course_id": course_id,
            "score": 15,
            "max_score": 20,
            "scheduled_at": "2026-11-01T10:00:00Z",
        },
    )
    client.post("/api/v1/evaluations", json={"title": "Not graded yet"})

    response = client.get("/api/v1/evaluations/summary")
    assert response.status_code == 200
    summary = response.json()
    assert summary["graded_count"] == 2
    assert summary["average_percentage"] == 77.5
    assert summary["course_averages"][0]["course_id"] == course_id
    assert summary["course_averages"][0]["evaluation_count"] == 2
    assert [point["title"] for point in summary["trend"]] == ["Quiz 1", "Quiz 2"]


def test_event_crud_and_timezone_validation(client):
    invalid = client.post(
        "/api/v1/events",
        json={
            "title": "No timezone",
            "starts_at": "2026-11-03T10:00:00",
        },
    )
    assert invalid.status_code == 422

    response = client.post(
        "/api/v1/events",
        json={
            "title": "Study session",
            "starts_at": "2026-11-03T10:00:00Z",
            "ends_at": "2026-11-03T11:00:00Z",
        },
    )
    assert response.status_code == 201
    event_id = response.json()["id"]

    invalid = client.put(
        f"/api/v1/events/{event_id}",
        json={"ends_at": "2026-11-03T09:00:00Z"},
    )
    assert invalid.status_code == 422
    response = client.put(
        f"/api/v1/events/{event_id}",
        json={"title": "Focused study"},
    )
    assert response.status_code == 200
    assert response.json()["title"] == "Focused study"
    assert client.get(f"/api/v1/events/{event_id}").status_code == 200
    assert client.get("/api/v1/events").status_code == 200
    assert client.delete(f"/api/v1/events/{event_id}").status_code == 204


def test_notification_list_and_read_are_scoped(client, db_session):
    db_session.add(User(firebase_uid="firebase-user-a"))
    db_session.add(User(firebase_uid="firebase-user-b"))
    own = Notification(
        owner_uid="firebase-user-a",
        notification_type="task_due",
        title="Task due",
        body="Review the task",
    )
    other = Notification(
        owner_uid="firebase-user-b",
        notification_type="task_due",
        title="Private",
        body="Other user",
    )
    db_session.add_all([own, other])
    db_session.commit()

    response = client.get("/api/v1/notifications?limit=10&offset=0")
    assert response.status_code == 200
    assert [item["title"] for item in response.json()] == ["Task due"]

    response = client.put(f"/api/v1/notifications/{own.id}/read")
    assert response.status_code == 200
    assert response.json()["read_at"] is not None
    assert client.put(f"/api/v1/notifications/{other.id}/read").status_code == 404
    assert client.put(f"/api/v1/notifications/{uuid4()}/read").status_code == 404

    app.dependency_overrides[get_current_uid] = lambda: "firebase-user-b"
    response = client.get("/api/v1/notifications")
    assert response.status_code == 200
    assert [item["title"] for item in response.json()] == ["Private"]


def test_all_private_resource_groups_require_authentication(client):
    app.dependency_overrides.pop(get_current_uid)
    for path in (
        "/api/v1/users/me",
        "/api/v1/profile",
        "/api/v1/flashcards",
        "/api/v1/evaluations",
        "/api/v1/events",
        "/api/v1/notifications",
    ):
        response = client.get(path)
        assert response.status_code == 401, path
