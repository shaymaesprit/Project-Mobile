import logging
from collections.abc import Generator

from fastapi import HTTPException, status
from sqlalchemy import Connection, create_engine, event, text
from sqlalchemy.exc import InterfaceError, OperationalError, TimeoutError as SQLAlchemyTimeoutError
from sqlalchemy.orm import Session, SessionTransaction, sessionmaker

from app.core.config import get_settings

logger = logging.getLogger(__name__)

engine = create_engine(
    get_settings().database_url.get_secret_value(),
    pool_pre_ping=True,
    hide_parameters=True,
)

SessionLocal = sessionmaker(
    bind=engine,
    autoflush=False,
    expire_on_commit=False,
)


@event.listens_for(Session, "after_begin")
def _set_verified_tenant(
    session: Session,
    transaction: SessionTransaction,
    connection: Connection,
) -> None:
    firebase_uid = session.info.get("firebase_uid")
    if firebase_uid and connection.dialect.name == "postgresql":
        connection.execute(
            text("SELECT set_config('app.firebase_uid', :firebase_uid, true)"),
            {"firebase_uid": firebase_uid},
        )


def get_db() -> Generator[Session, None, None]:
    with SessionLocal() as session:
        try:
            yield session
        except (OperationalError, InterfaceError, SQLAlchemyTimeoutError) as error:
            session.rollback()
            logger.error(
                "PostgreSQL connection failed (%s).",
                type(error).__name__,
            )
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail="The database is temporarily unavailable.",
            ) from error
