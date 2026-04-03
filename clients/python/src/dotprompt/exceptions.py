"""Custom exceptions for dot-prompt client."""


class DotPromptError(Exception):
    """Base exception for all dot-prompt errors."""

    pass


class ConnectionError(DotPromptError):
    """Raised when unable to connect to the container."""

    def __init__(self, message: str = "Unable to connect to dot-prompt container") -> None:
        super().__init__(message)


class TimeoutError(DotPromptError):
    """Raised when a request times out."""

    def __init__(self, message: str = "Request timed out") -> None:
        super().__init__(message)


class APIClientError(DotPromptError):
    """Base class for 4xx API errors."""

    def __init__(self, status_code: int, message: str) -> None:
        self.status_code = status_code
        super().__init__(message)


class MissingRequiredParamsError(APIClientError):
    """Raised when required parameters are missing."""

    def __init__(self, message: str = "Missing required parameters") -> None:
        super().__init__(422, message)


class PromptNotFoundError(APIClientError):
    """Raised when the requested prompt is not found."""

    def __init__(self, prompt_name: str) -> None:
        self.prompt_name = prompt_name
        super().__init__(404, f"Prompt not found: {prompt_name}")


class ValidationError(APIClientError):
    """Raised when validation fails."""

    def __init__(self, message: str) -> None:
        super().__init__(422, message)


class ServerError(DotPromptError):
    """Raised when the server returns a 5xx error."""

    def __init__(self, status_code: int, message: str = "Server error") -> None:
        self.status_code = status_code
        super().__init__(f"Server error ({status_code}): {message}")
