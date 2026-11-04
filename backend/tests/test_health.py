import pytest
from fastapi import HTTPException
from sqlalchemy.exc import OperationalError

from app.database.connection import get_db
from app.core.config import get_settings


def test_health_endpoints_report_database_connection(client):
    assert client.get("/api/v1/health").json() == {
        "status": "ok",
        "database": "connected",
    }
    assert client.get("/api/v1/health/database").json() == {
        "status": "ok",
        "database": "connected",
    }


def test_swagger_and_openapi_are_available(client):
    docs = client.get("/docs")
    assert docs.status_code == 200
    assert "swagger-ui" in docs.text

    schema = client.get("/openapi.json")
    assert schema.status_code == 200
    assert schema.json()["info"]["title"] == "StudyMate API"
    assert "/api/v1/health" in schema.json()["paths"]


def test_cors_allows_configured_flutter_web_origin(client):
    origin = "http://localhost:5173"
    response = client.options(
        "/api/v1/health",
        headers={
            "Origin": origin,
            "Access-Control-Request-Method": "GET",
            "Access-Control-Request-Headers": "authorization",
        },
    )

    assert response.status_code == 200
    assert response.headers["access-control-allow-origin"] == origin


def test_database_url_is_masked_in_configuration():
    assert str(get_settings().database_url) == "**********"


def test_database_dependency_masks_connection_errors():
    dependency = get_db()
    next(dependency)

    with pytest.raises(HTTPException) as raised:
        dependency.throw(OperationalError("SELECT 1", {}, RuntimeError("unavailable")))

    assert raised.value.status_code == 503
    assert raised.value.detail == "The database is temporarily unavailable."
