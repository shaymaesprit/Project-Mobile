from sqlalchemy.orm import Session

from app.models.user import User


class UserRepository:
    def __init__(self, db: Session) -> None:
        self._db = db

    def get_by_uid(self, firebase_uid: str) -> User | None:
        return self._db.get(User, firebase_uid)

    def create(
        self,
        firebase_uid: str,
        profile: dict[str, str] | None = None,
    ) -> User:
        user = User(firebase_uid=firebase_uid, **(profile or {}))
        self._db.add(user)
        self._db.commit()
        self._db.refresh(user)
        return user

    def update(self, user: User, changes: dict) -> User:
        for field, value in changes.items():
            setattr(user, field, value)
        self._db.commit()
        self._db.refresh(user)
        return user

    def delete(self, user: User) -> None:
        self._db.delete(user)
        self._db.commit()
