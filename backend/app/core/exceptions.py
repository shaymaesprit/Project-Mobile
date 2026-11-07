class StudyMateError(Exception):
    status_code = 400
    code = "studymate_error"

    def __init__(self, detail: str) -> None:
        super().__init__(detail)
        self.detail = detail


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
