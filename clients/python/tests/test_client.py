"""Tests for sync client."""

from unittest.mock import AsyncMock, MagicMock, patch

import pytest

from dotprompt.client import DotPromptClient
from dotprompt.models import CompileResult, PromptSchema


@pytest.fixture
def client():
    with patch("dotprompt.client.DotPromptAsyncClient") as mock:
        mock_instance = MagicMock()
        mock_instance.list_prompts = AsyncMock(return_value=["prompt1", "prompt2"])
        mock_instance.list_collections = AsyncMock(return_value=["collection1"])
        mock_instance.close = AsyncMock()
        mock_instance.get_schema = AsyncMock()
        mock_instance.compile = AsyncMock()
        mock_instance.render = AsyncMock()
        mock_instance.inject = AsyncMock()
        mock_instance.events = AsyncMock()
        mock_instance.validate_response = AsyncMock(return_value=True)
        mock.return_value = mock_instance
        yield mock_instance


def test_list_prompts(client):
    with patch("dotprompt.client.DotPromptAsyncClient") as mock:
        mock_instance = MagicMock()
        mock_instance.list_prompts = AsyncMock(return_value=["prompt1", "prompt2"])
        mock_instance.close = AsyncMock()
        mock.return_value = mock_instance

        sync_client = DotPromptClient(base_url="http://localhost:4041")
        sync_client._async_client = mock_instance

        result = sync_client.list_prompts()
        assert result == ["prompt1", "prompt2"]


def test_list_collections(client):
    with patch("dotprompt.client.DotPromptAsyncClient") as mock:
        mock_instance = MagicMock()
        mock_instance.list_collections = AsyncMock(return_value=["collection1"])
        mock_instance.close = AsyncMock()
        mock.return_value = mock_instance

        sync_client = DotPromptClient(base_url="http://localhost:4041")
        sync_client._async_client = mock_instance

        result = sync_client.list_collections()
        assert result == ["collection1"]


def test_get_schema(client):
    mock_schema = PromptSchema(
        name="test_prompt",
        version=1,
        description="Test",
        params={},
        fragments={},
    )

    with patch("dotprompt.client.DotPromptAsyncClient") as mock:
        mock_instance = MagicMock()
        mock_instance.get_schema = AsyncMock(return_value=mock_schema)
        mock_instance.close = AsyncMock()
        mock.return_value = mock_instance

        sync_client = DotPromptClient(base_url="http://localhost:4041")
        sync_client._async_client = mock_instance

        result = sync_client.get_schema("test_prompt")
        assert result.name == "test_prompt"


def test_compile(client):
    mock_result = CompileResult(
        template="Hello {name}",
        cache_hit=False,
        compiled_tokens=10,
        version=1,
        warnings=[],
    )

    with patch("dotprompt.client.DotPromptAsyncClient") as mock:
        mock_instance = MagicMock()
        mock_instance.compile = AsyncMock(return_value=mock_result)
        mock_instance.close = AsyncMock()
        mock.return_value = mock_instance

        sync_client = DotPromptClient(base_url="http://localhost:4041")
        sync_client._async_client = mock_instance

        result = sync_client.compile("test_prompt", params={"name": "world"})
        assert result.template == "Hello {name}"


def test_validate_response(client):
    with patch("dotprompt.client.DotPromptAsyncClient") as mock:
        mock_instance = MagicMock()
        mock_instance.validate_response = AsyncMock(return_value=True)
        mock_instance.close = AsyncMock()
        mock.return_value = mock_instance

        sync_client = DotPromptClient(base_url="http://localhost:4041")
        sync_client._async_client = mock_instance

        contract = {"fields": {"answer": {"type": "string"}}}
        response = {"answer": "test"}

        result = sync_client.validate_response(response, contract)
        assert result is True


def test_close(client):
    with patch("dotprompt.client.DotPromptAsyncClient") as mock:
        mock_instance = MagicMock()
        mock_instance.close = AsyncMock()
        mock.return_value = mock_instance

        sync_client = DotPromptClient(base_url="http://localhost:4041")
        sync_client._async_client = mock_instance

        sync_client.close()
        mock_instance.close.assert_called_once()
