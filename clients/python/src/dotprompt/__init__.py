"""Dotprompt Python client library."""

from dotprompt.async_client import DotPromptAsyncClient
from dotprompt.client import DotPromptClient
from dotprompt.events import Event
from dotprompt.exceptions import (
    APIClientError,
    ConnectionError,
    DotPromptError,
    MissingRequiredParamsError,
    PromptNotFoundError,
    ServerError,
    TimeoutError,
    ValidationError,
)
from dotprompt.models import (
    CompileResult,
    ContractField,
    FragmentSpec,
    InjectResult,
    ParamSpec,
    PromptSchema,
    RenderResult,
    ResponseContract,
)

__version__ = "0.1.0"

__all__ = [
    "DotPromptClient",
    "DotPromptAsyncClient",
    "Event",
    "DotPromptError",
    "ConnectionError",
    "TimeoutError",
    "APIClientError",
    "MissingRequiredParamsError",
    "PromptNotFoundError",
    "ValidationError",
    "ServerError",
    "CompileResult",
    "ContractField",
    "FragmentSpec",
    "InjectResult",
    "ParamSpec",
    "PromptSchema",
    "RenderResult",
    "ResponseContract",
]
