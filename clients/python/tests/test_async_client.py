"""Tests for async client."""

from unittest.mock import AsyncMock, patch

import pytest
import pytest_asyncio

from dotprompt.async_client import DotPromptAsyncClient
from dotprompt.models import CompileResult, PromptSchema


@pytest_asyncio.fixture
async def client():
    with patch("dotprompt.async_client._Transport") as mock:
        mock_instance = mock.return_value
        mock_instance.get = AsyncMock(return_value={"prompts": []})
        mock_instance.post = AsyncMock(return_value={})
        mock_instance.close = AsyncMock()
        client = DotPromptAsyncClient(base_url="http://localhost:4041")
        client._transport = mock_instance
        yield client
        await client.close()


@pytest.mark.asyncio
async def test_list_prompts(client):
    client._transport.get = AsyncMock(return_value={"prompts": ["prompt1", "prompt2"]})

    result = await client.list_prompts()

    assert result == ["prompt1", "prompt2"]


@pytest.mark.asyncio
async def test_list_collections(client):
    client._transport.get = AsyncMock(return_value={"collections": ["collection1"]})

    result = await client.list_collections()

    assert result == ["collection1"]


@pytest.mark.asyncio
async def test_get_schema(client):
    client._transport.get = AsyncMock(
        return_value={
            "name": "test_prompt",
            "version": 1,
            "description": "Test prompt",
            "params": {},
            "fragments": {},
        }
    )

    result = await client.get_schema("test_prompt")

    assert isinstance(result, PromptSchema)
    assert result.name == "test_prompt"


@pytest.mark.asyncio
async def test_compile(client):
    client._transport.post = AsyncMock(
        return_value={
            "template": "Hello {name}",
            "cache_hit": False,
            "compiled_tokens": 10,
            "response_contract": None,
            "version": 1,
            "warnings": [],
        }
    )

    result = await client.compile("test_prompt", params={"name": "world"})

    assert isinstance(result, CompileResult)
    assert result.template == "Hello {name}"


@pytest.mark.asyncio
async def test_validate_response(client):
    contract = {
        "fields": {
            "answer": {"type": "string"},
            "confidence": {"type": "number"},
        }
    }
    response = {"answer": "test", "confidence": 0.9}

    result = await client.validate_response(response, contract)

    assert result is True


@pytest.mark.asyncio
async def test_validate_response_invalid(client):
    contract = {
        "properties": {
            "answer": {"type": "string"},
        }
    }
    response = {"answer": 123}

    result = await client.validate_response(response, contract)

    assert result is False
