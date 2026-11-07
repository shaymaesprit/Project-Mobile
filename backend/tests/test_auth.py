import pytest
from fastapi.testclient import TestClient
from firebase_admin import auth as firebase_auth

from app.api import deps
from app.database.session import get_db
from app.main import app


@pytest.fixture
def raw_client(db_session):
    """Client that exercises the real Firebase token dependency."""
    app.dependency_overrides[get_db] = lambda: db_session
    with TestClient(app) as test_client:
        yield test_client
    app.dependency_overrides.clear()


@pytest.fixture
def firebase(monkeypatch):
    """Replaces Firebase Admin with a controllable fake."""
    state = {"claims": {}, "error": None, "revoked": []}

    def fake_verify(token, app=None, check_revoked=False):
        assert check_revoked is True
        if state["error"] is not None:
            raise state["error"]
        return state["claims"]

    monkeypatch.setattr(deps, "_firebase_app", lambda: object())
    monkeypatch.setattr(deps.firebase_auth, "verify_id_token", fake_verify)
    monkeypatch.setattr(
        deps.firebase_auth,
        "revoke_refresh_tokens",
        lambda uid, app=None: state["revoked"].append(uid),
    )
    return state


def _auth(token="token"):
    return {"Authorization": f"Bearer {token}"}


def test_missing_bearer_token_is_rejected(raw_client, firebase):
    response = raw_client.get("/api/v1/users/me")
    assert response.status_code == 401
    assert response.headers["WWW-Authenticate"] == "Bearer"


def test_invalid_token_is_rejected(raw_client, firebase):
    firebase["error"] = firebase_auth.InvalidIdTokenError("bad token")
    response = raw_client.get("/api/v1/users/me", headers=_auth())
    assert response.status_code == 401
    assert "invalid" in response.json()["detail"].lower()


def test_expired_token_is_rejected(raw_client, firebase):
    firebase["error"] = firebase_auth.ExpiredIdTokenError("expired", cause=None)
    response = raw_client.get("/api/v1/users/me", headers=_auth())
    assert response.status_code == 401
    assert "expired" in response.json()["detail"].lower()


def test_revoked_token_is_rejected(raw_client, firebase):
    firebase["error"] = firebase_auth.RevokedIdTokenError("revoked")
    response = raw_client.get("/api/v1/users/me", headers=_auth())
    assert response.status_code == 401


def test_token_without_uid_is_rejected(raw_client, firebase):
    firebase["claims"] = {"email": "a@univ.tn"}
    response = raw_client.get("/api/v1/users/me", headers=_auth())
    assert response.status_code == 401


def test_uid_comes_only_from_verified_token(raw_client, firebase):
    firebase["claims"] = {"uid": "uid-a", "email": "a@univ.tn", "name": "Ada"}
    response = raw_client.get(
        "/api/v1/users/me",
        headers={**_auth(), "X-User-Id": "uid-b"},
        params={"firebase_uid": "uid-b"},
    )
    assert response.status_code == 200
    assert response.json()["firebase_uid"] == "uid-a"


def test_session_reports_verified_claims(raw_client, firebase):
    firebase["claims"] = {
        "uid": "uid-a",
        "email": "a@univ.tn",
        "email_verified": True,
        "exp": 1_900_000_000,
        "firebase": {"sign_in_provider": "password"},
    }
    response = raw_client.get("/api/v1/auth/session", headers=_auth())
    assert response.status_code == 200
    assert response.json() == {
        "firebase_uid": "uid-a",
        "email": "a@univ.tn",
        "email_verified": True,
        "sign_in_provider": "password",
        "expires_at": 1_900_000_000,
    }


def test_logout_all_revokes_refresh_tokens_of_caller_only(raw_client, firebase):
    firebase["claims"] = {"uid": "uid-a"}
    response = raw_client.post("/api/v1/auth/logout-all", headers=_auth())
    assert response.status_code == 204
    assert firebase["revoked"] == ["uid-a"]


def test_logout_all_requires_authentication(raw_client, firebase):
    response = raw_client.post("/api/v1/auth/logout-all")
    assert response.status_code == 401
    assert firebase["revoked"] == []
