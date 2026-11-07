from collections.abc import Generator

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import Session, sessionmaker
from sqlalchemy.pool import StaticPool

from app.api.deps import get_current_uid
from app.database.base import Base
from app.database.session import get_db
from app.main import app
from app import models  # noqa: F401

test_engine = create_engine(
    "sqlite://",
    connect_args={"check_same_thread": False},
    poolclass=StaticPool,
)
TestSession = sessionmaker(bind=test_engine, autoflush=False, expire_on_commit=False)


@pytest.fixture(autouse=True)
def isolate_external_services(monkeypatch):
    """Never reach Firebase (Firestore/FCM/Storage) or keep rate-limit state in tests."""
    from app.services import firebase_service

    app.state.rate_limiter.reset()
    monkeypatch.setattr(firebase_service, "sync_notification", lambda *a, **k: True)
    monkeypatch.setattr(firebase_service, "sync_realtime_status", lambda *a, **k: True)
    monkeypatch.setattr(firebase_service, "sync_focus_session", lambda *a, **k: True)
    monkeypatch.setattr(firebase_service, "send_push", lambda *a, **k: [])
    monkeypatch.setattr(
        firebase_service,
        "delete_user_cloud_data",
        lambda uid: {"firestore": True, "storage": True},
    )
    yield


@pytest.fixture
def db_session() -> Generator[Session, None, None]:
    Base.metadata.create_all(test_engine)
    with TestSession() as session:
        yield session
    Base.metadata.drop_all(test_engine)


@pytest.fixture
def client(db_session: Session) -> Generator[TestClient, None, None]:
    app.dependency_overrides[get_db] = lambda: db_session
    app.dependency_overrides[get_current_uid] = lambda: "firebase-user-a"
    with TestClient(app) as test_client:
        yield test_client
    app.dependency_overrides.clear()
