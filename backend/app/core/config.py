from functools import lru_cache
from pathlib import Path
from typing import Literal

from pydantic import Field, SecretStr
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    database_url: SecretStr
    app_name: str = "StudyMate API"
    app_version: str = "0.3.0"
    debug: bool = False
    log_level: Literal["DEBUG", "INFO", "WARNING", "ERROR", "CRITICAL"] = "INFO"
    firebase_project_id: str = ""
    google_application_credentials: str = ""
    llm_provider: Literal["none", "openai"] = "none"
    llm_api_key: SecretStr | None = None
    llm_model: str = "gpt-4o-mini"
    llm_base_url: str = "https://api.openai.com/v1"
    llm_timeout_seconds: float = Field(default=20.0, gt=0, le=120)
    rate_limit_per_minute: int = Field(default=240, ge=0)
    rate_limit_ai_per_minute: int = Field(default=20, ge=0)
    cors_origin_regex: str | None = r"^https?://(localhost|127\.0\.0\.1)(:\d+)?$"
    cors_origins: list[str] = Field(
        default_factory=lambda: [
            "http://localhost",
            "http://127.0.0.1",
            "http://localhost:3000",
            "http://127.0.0.1:3000",
        ]
    )

    model_config = SettingsConfigDict(
        env_file=Path(__file__).resolve().parents[2] / ".env",
        env_file_encoding="utf-8",
        case_sensitive=False,
        extra="ignore",
    )


@lru_cache
def get_settings() -> Settings:
    return Settings()
