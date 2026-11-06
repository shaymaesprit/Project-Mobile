import logging

from fastapi import FastAPI, Request
from fastapi.exceptions import RequestValidationError
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from fastapi.exception_handlers import request_validation_exception_handler
from sqlalchemy.exc import InterfaceError, OperationalError, TimeoutError as SQLAlchemyTimeoutError

from app.api.router import api_router
from app.core.config import get_settings
from app.core.exceptions import StudyMateError
from app.core.logging import configure_logging

settings = get_settings()
configure_logging(settings.log_level)
logger = logging.getLogger("studymate.api")

app = FastAPI(
    title=settings.app_name,
    description=(
        "StudyMate API for student courses, tasks, notes, flashcards, and "
        "evaluations. "
        "Protected resources require a Firebase ID token."
    ),
    version=settings.app_version,
    debug=settings.debug,
    docs_url="/docs",
    redoc_url="/redoc",
    openapi_url="/openapi.json",
    openapi_tags=[
        {"name": "health", "description": "API and PostgreSQL availability."},
        {"name": "authentication", "description": "Current Firebase user."},
        {"name": "courses", "description": "User-owned courses."},
        {"name": "tasks", "description": "User-owned study tasks."},
        {"name": "notes", "description": "User-owned study notes."},
        {"name": "flashcards", "description": "User-owned flashcards and review history."},
        {"name": "flashcard decks", "description": "User-owned flashcard sets."},
        {"name": "evaluations", "description": "User-owned grades and progress."},
    ],
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins,
    allow_origin_regex=settings.cors_origin_regex,
    allow_credentials=False,
    allow_methods=["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"],
    allow_headers=["Authorization", "Content-Type"],
)


@app.middleware("http")
async def log_request(request: Request, call_next):
    response = await call_next(request)
    logger.info(
        "%s %s -> %s",
        request.method,
        request.url.path,
        response.status_code,
    )
    return response


@app.exception_handler(StudyMateError)
async def studymate_exception_handler(
    request: Request,
    error: StudyMateError,
) -> JSONResponse:
    logger.info(
        "Request failed with %s on %s.",
        error.code,
        request.url.path,
    )
    return JSONResponse(
        status_code=error.status_code,
        content={"detail": error.detail, "code": error.code},
    )


async def database_exception_handler(
    request: Request,
    error: Exception,
) -> JSONResponse:
    logger.error(
        "Database unavailable for %s %s (%s).",
        request.method,
        request.url.path,
        type(error).__name__,
    )
    return JSONResponse(
        status_code=503,
        content={"detail": "The database is temporarily unavailable."},
    )


for database_error in (
    OperationalError,
    InterfaceError,
    SQLAlchemyTimeoutError,
):
    app.add_exception_handler(database_error, database_exception_handler)


@app.exception_handler(RequestValidationError)
async def validation_exception_handler(
    request: Request,
    error: RequestValidationError,
) -> JSONResponse:
    logger.info("Invalid request to %s.", request.url.path)
    return await request_validation_exception_handler(request, error)


@app.exception_handler(Exception)
async def unhandled_exception_handler(
    request: Request,
    error: Exception,
) -> JSONResponse:
    logger.error(
        "Unhandled request failure on %s (%s).",
        request.url.path,
        type(error).__name__,
    )
    return JSONResponse(
        status_code=500,
        content={"detail": "An unexpected server error occurred."},
    )


app.include_router(api_router, prefix="/api/v1")
