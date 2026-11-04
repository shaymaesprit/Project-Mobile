from app.repositories.health_repository import HealthRepository


class HealthService:
    def __init__(self, repository: HealthRepository) -> None:
        self._repository = repository

    def check(self) -> dict[str, str]:
        self._repository.check_database()
        return {"status": "ok", "database": "connected"}
