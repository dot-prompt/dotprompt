"""Async client for dot-prompt."""

from typing import Any, AsyncIterator

import httpx

from dotprompt._transport import _Transport
from dotprompt.exceptions import (
    APIClientError,
    ConnectionError,
    MissingRequiredParamsError,
    PromptNotFoundError,
    ServerError,
    TimeoutError,
    ValidationError,
)
from dotprompt.models import CompileResult, PromptSchema


class DotPromptAsyncClient:
    """Async-first client for interacting with the dot-prompt container API."""

    def __init__(self, base_url: str = "http://localhost:4000", **kwargs):
        self._transport = _Transport(base_url=base_url, **kwargs)

    async def __aenter__(self):
        return self

    async def __aexit__(self, exc_type, exc_val, exc_tb):
        await self.close()

    async def close(self) -> None:
        """Close the HTTP client."""
        await self._transport.close()

    async def list_prompts(self) -> list[str]:
        """List all available prompts."""
        response = await self._transport.get("/api/prompts")
        return response.get("prompts", [])

    async def list_collections(self) -> list[str]:
        """List all available prompt collections."""
        response = await self._transport.get("/api/collections")
        return response.get("collections", [])

    async def get_schema(self, prompt_name: str) -> PromptSchema:
        """Get the schema for a specific prompt."""
        data = await self._transport.get(f"/api/schema/{prompt_name}")
        return PromptSchema(**data)

    async def compile(
        self,
        prompt: str,
        params: dict[str, Any],
        options: dict[str, Any] | None = None,
    ) -> CompileResult:
        """Compile a prompt with the given parameters."""
        options = options or {}
        body = {
            "prompt": prompt,
            "params": params,
        }
        if "seed" in options:
            body["seed"] = options["seed"]
        if "version" in options:
            body["version"] = options["version"]

        data = await self._transport.post("/api/compile", body)
        return CompileResult(**data)

    async def render(
        self,
        prompt: str,
        params: dict[str, Any],
        runtime: dict[str, Any] | None = None,
        options: dict[str, Any] | None = None,
    ) -> dict[str, Any]:
        """Render a prompt (compile + fill in variables)."""
        options = options or {}
        body = {
            "prompt": prompt,
            "params": params,
            "runtime": runtime or {},
        }
        if "seed" in options:
            body["seed"] = options["seed"]
        if "version" in options:
            body["version"] = options["version"]

        return await self._transport.post("/api/render", body)

    async def inject(
        self,
        template: str,
        runtime: dict[str, str],
    ) -> dict[str, Any]:
        """Inject runtime variables into a template string."""
        return await self._transport.post("/api/inject", {
            "template": template,
            "runtime": runtime,
        })

    async def validate_response(self, response: dict, contract: dict) -> bool:
        """Validate LLM response against a response contract.
        
        Args:
            response: The LLM response to validate.
            contract: The response contract definition.
        
        Returns:
            True if the response matches the contract, False otherwise.
        """
        # Elixir returns contract with "properties" key, not "fields"
        properties = contract.get("properties", {})
        
        for field_name, field_spec in properties.items():
            if field_name not in response:
                return False
            
            expected_type = field_spec.get("type")
            actual_value = response[field_name]
            
            # Check type
            if expected_type and not self._check_type(actual_value, expected_type):
                return False
        
        return True

    def _check_type(self, value: Any, type_str: str) -> bool:
        """Check if a value matches the expected type."""
        type_mapping = {
            "string": str,
            "number": (int, float),
            "integer": int,
            "boolean": bool,
            "array": list,
            "object": dict,
            "null": type(None),
        }
        
        expected_type = type_mapping.get(type_str)
        if expected_type is None:
            return True
        
        if expected_type == type(None):
            return value is None
        
        return isinstance(value, expected_type)

    @staticmethod
    def _type_mapping(type_str: str):
        """Map type string to Python type (for backwards compatibility)."""
        mapping = {
            "string": str,
            "number": (int, float),
            "integer": int,
            "boolean": bool,
            "array": list,
            "object": dict,
        }
        return mapping.get(type_str, str)
