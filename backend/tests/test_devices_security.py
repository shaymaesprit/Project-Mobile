from app.core.rate_limit import RateLimiter
from app.main import app


def test_register_and_unregister_device(client):
    token = "t" * 40
    response = client.post(
        "/api/v1/users/me/devices",
        json={"fcm_token": token, "platform": "android", "device_name": " Pixel "},
    )
    assert response.status_code == 201
    device = response.json()
    assert device["device_name"] == "Pixel"
    assert "fcm_token" not in device

    again = client.post(
        "/api/v1/users/me/devices", json={"fcm_token": token, "platform": "android"}
    )
    assert again.status_code == 201 and again.json()["id"] == device["id"]

    assert client.delete(f"/api/v1/users/me/devices/{device['id']}").status_code == 204
    assert client.delete(f"/api/v1/users/me/devices/{device['id']}").status_code == 404


def test_device_validation(client):
    assert client.post(
        "/api/v1/users/me/devices", json={"fcm_token": "short", "platform": "android"}
    ).status_code == 422
    assert client.post(
        "/api/v1/users/me/devices", json={"fcm_token": "t" * 40, "platform": "toaster"}
    ).status_code == 422


def test_device_cannot_be_removed_by_another_user(client):
    from app.api.deps import get_current_uid

    device = client.post(
        "/api/v1/users/me/devices", json={"fcm_token": "k" * 40, "platform": "ios"}
    ).json()
    app.dependency_overrides[get_current_uid] = lambda: "firebase-user-b"
    assert client.delete(f"/api/v1/users/me/devices/{device['id']}").status_code == 404


def test_push_dispatch_removes_invalid_tokens(client, monkeypatch):
    from app.services import firebase_service

    token = "z" * 40
    device = client.post(
        "/api/v1/users/me/devices", json={"fcm_token": token, "platform": "android"}
    ).json()
    sent = []
    monkeypatch.setattr(
        firebase_service, "send_push",
        lambda tokens, title, body, data=None: (sent.append(tokens), tokens)[1],
    )
    response = client.post("/api/v1/notifications/test")
    assert response.status_code == 201
    assert response.json()["sent_at"] is not None
    assert sent == [[token]]
    # the invalid token was pruned
    assert client.delete(f"/api/v1/users/me/devices/{device['id']}").status_code == 404


def test_rate_limit_returns_429_with_retry_after(client):
    limiter: RateLimiter = app.state.rate_limiter
    original = (limiter.general_limit, limiter.ai_limit)
    limiter.general_limit, limiter.ai_limit = 1000, 2
    try:
        statuses = [client.get("/api/v1/ai/consent").status_code for _ in range(3)]
        assert statuses == [200, 200, 429]
        blocked = client.get("/api/v1/ai/consent")
        assert blocked.headers["retry-after"]
        assert blocked.json()["code"] == "rate_limited"
        assert client.get("/api/v1/profile").status_code == 200
    finally:
        limiter.general_limit, limiter.ai_limit = original


def test_account_deletion_cleans_cloud_data(client, monkeypatch):
    from app.services import firebase_service

    calls = []
    monkeypatch.setattr("app.api.routes.users.delete_firebase_account", lambda uid: None)
    monkeypatch.setattr(
        firebase_service, "delete_user_cloud_data",
        lambda uid: (calls.append(uid), {"firestore": True, "storage": True})[1],
    )
    assert client.delete("/api/v1/users/me").status_code == 204
    assert calls == ["firebase-user-a"]
