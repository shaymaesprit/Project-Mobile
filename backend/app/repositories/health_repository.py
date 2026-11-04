from sqlalchemy import text
from sqlalchemy.orm import Session


class HealthRepository:
    def __init__(self, db: Session) -> None:
        self._db = db

    def check_database(self) -> None:
        self._db.execute(text("SELECT 1"))
