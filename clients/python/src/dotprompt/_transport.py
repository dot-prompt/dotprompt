"""Private HTTP transport layer for dot-prompt client."""

import logging
from typing import Any, AsyncIterator

import httpx

from dotprompt.exceptions import (
    APIClientError,
    ConnectionError,
    MissingRequiredParamsError,
    PromptNotFoundError,
    ServerError,
    TimeoutError,
    ValidationError,
)

logger = logging.getLogger(__name__)


class _Transport:
    """Private transport layer for HTTP communication with dot-prompt container."""

    def __init__(
        self,
        base_url: str = "http://localhost:4041",
        timeout: float = 30.0,
        verify_ssl: bool = True,
        api_key: str | None = None,
        max_retries: int = 3,
    ):
        self.base_url = base_url.rstrip("/")
        self.timeout = timeout
        self.verify_ssl = verify_ssl
        self.api_key = api_key
        self.max_retries = max_retries
        self._client = httpx.AsyncClient(
            base_url=self.base_url,
            timeout=timeout,
            verify=verify_ssl,
            headers=self._build_headers(api_key),
        )

    def _build_headers(self, api_key: str | None = None) -> dict[str, str]:
        headers = {"Content-Type": "application/json"}
        if api_key:
            headers["Authorization"] = f"Bearer {api_key}"
        return headers

    async def close(self) -> None:
        """Close the HTTP client."""
        await self._client.aclose()

    async def get(self, path: str) -> dict[str, Any]:
        """Perform GET request."""
        return await self._do_request("GET", path)

    async def post(self, path: str, body: dict[str, Any]) -> dict[str, Any]:
        """Perform POST request."""
        return await self._do_request("POST", path, json=body)

    async def _do_request(
        self, method: str, path: str, **kwargs: Any
    ) -> dict[str, Any]:
        """Execute HTTP request with retry logic."""
        last_error = None

        for attempt in range(self.max_retries):
            try:
                response = await self._client.request(
                    method, path, **kwargs
                )

                if response.status_code >= 400:
                    self._handle_error(response)

                return response.json()

            except httpx.TimeoutException as e:
                last_error = e
                if attempt == self.max_retries - 1:
                    raise TimeoutError(f"Request to {path} timed out") from e

            except httpx.ConnectError as e:
                last_error = e
                if attempt == self.max_retries - 1:
                    raise ConnectionError(
                        f"Could not connect to dot-prompt server at {self.base_url}"
                    ) from e

        raise ServerError(f"Request failed after {self.max_retries} attempts") from last_error

    def _handle_error(self, response: httpx.Response) -> None:
        """Handle HTTP error responses."""
        status = response.status_code
        try:
            error_data = response.json()
            error_type = error_data.get("error", "server_error")
            message = error_data.get("message", "Unknown error")
        except Exception:
            error_type = "server_error"
            message = response.text or "Unknown error"

        error_mapping = {
            400: ValidationError,
            404: PromptNotFoundError,
            422: MissingRequiredParamsError,
            500: ServerError,
            502: ServerError,
            503: ServerError,
        }

        error_class = error_mapping.get(status, APIClientError)
        raise error_class(message)

    import contextlib

    @contextlib.asynccontextmanager
    async def stream(self, method: str, path: str, **kwargs: Any) -> AsyncIterator[httpx.Response]:
        """Context manager for streaming requests."""
        async with self._client.stream(method, path, **kwargs) as response:
            if response.status_code >= 400:
                self._handle_error(response)
            yield response
