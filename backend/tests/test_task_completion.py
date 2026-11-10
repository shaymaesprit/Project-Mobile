from app.models.task import StudyTask


def test_ticking_a_task_keeps_status_consistent(client, db_session):
    """Régression : cocher une tâche violait ck_tasks_status_completed (500)."""
    task = client.post("/api/v1/tasks", json={"title": "Saif"}).json()

    done = client.patch(f"/api/v1/tasks/{task['id']}", json={"is_completed": True})
    assert done.status_code == 200, done.text
    assert done.json()["is_completed"] is True
    row = db_session.get(StudyTask, __import__("uuid").UUID(task["id"]))
    assert row.status == "completed" and row.completed_at is not None

    undone = client.patch(f"/api/v1/tasks/{task['id']}", json={"is_completed": False})
    assert undone.status_code == 200, undone.text
    db_session.refresh(row)
    assert row.status == "pending" and row.completed_at is None
