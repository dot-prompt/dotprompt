"""Pydantic models for dot-prompt API responses."""

from typing import Any

from pydantic import BaseModel


class ContractField(BaseModel):
    """Field in a response contract."""

    type: str
    doc: str | None = None


class ResponseContract(BaseModel):
    """Response contract defining expected output structure."""

    fields: dict[str, ContractField]
    compatible: bool


class ParamSpec(BaseModel):
    """Parameter specification from prompt schema."""

    type: str
    lifecycle: str | None = None
    doc: str | None = None
    default: Any | None = None
    values: list[Any] | None = None
    range: tuple | None = None


class FragmentSpec(BaseModel):
    """Fragment specification from prompt schema."""

    type: str
    doc: str | None = None
    from_path: str | None = None

    model_config = {"populate_by_name": True}


class PromptSchema(BaseModel):
    """Schema metadata for a prompt."""

    name: str
    version: int
    description: str | None = None
    mode: str | None = None
    docs: str | None = None
    params: dict[str, ParamSpec] = {}
    fragments: dict[str, FragmentSpec] = {}
    contract: ResponseContract | None = None


class CompileResult(BaseModel):
    """Result from compiling a prompt."""

    template: str
    cache_hit: bool
    compiled_tokens: int
    vary_selections: dict | None = None
    response_contract: dict | None = None
    version: int
    warnings: list[str] = []


class RenderResult(BaseModel):
    """Result from rendering a prompt with runtime injection."""

    prompt: str
    response_contract: dict | None = None
    cache_hit: bool
    compiled_tokens: int
    injected_tokens: int
    vary_selections: dict | None = None


class InjectResult(BaseModel):
    """Result from injecting runtime into a template."""

    prompt: str
    injected_tokens: int
