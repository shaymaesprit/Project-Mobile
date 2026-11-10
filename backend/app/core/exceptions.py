class StudyMateError(Exception):
    status_code = 400
    code = "studymate_error"

    def __init__(self, detail: str, extra: dict | None = None) -> None:
        super().__init__(detail)
        self.detail = detail
        # Données structurées facultatives renvoyées avec l'erreur.
        self.extra = extra or {}


class ResourceNotFoundError(StudyMateError):
    status_code = 404
    code = "resource_not_found"


class InvalidReferenceError(StudyMateError):
    status_code = 404
    code = "reference_not_found"


class InvalidResourceStateError(StudyMateError):
    status_code = 422
    code = "invalid_resource_state"


class CourseScheduleConflictError(StudyMateError):
    status_code = 409
    code = "course_schedule_conflict"


class AIConsentRequiredError(StudyMateError):
    status_code = 403
    code = "ai_consent_required"


class AIUnavailableError(StudyMateError):
    status_code = 503
    code = "ai_unavailable"


class ShareExpiredError(StudyMateError):
    status_code = 410
    code = "share_expired"


class PermissionDeniedError(StudyMateError):
    status_code = 403
    code = "permission_denied"


class PayloadTooLargeError(StudyMateError):
    status_code = 413
    code = "payload_too_large"


class EventScheduleConflictError(StudyMateError):
    status_code = 409
    code = "event_schedule_conflict"


class PlacesUnavailableError(StudyMateError):
    status_code = 503
    code = "places_unavailable"
