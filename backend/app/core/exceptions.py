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
