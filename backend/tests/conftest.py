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
