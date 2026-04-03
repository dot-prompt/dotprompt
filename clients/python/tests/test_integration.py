"""Integration tests for Python client against live container."""

import os
import pytest
import httpx

pytestmark = pytest.mark.skipif(
    not os.environ.get("DOT_PROMPT_URL"),
    reason="DOT_PROMPT_URL not set - run against live container"
)


@pytest.fixture
def base_url():
    return os.environ.get("DOT_PROMPT_URL", "http://localhost:4000")


class TestContractIntegration:
    """Integration tests for contract handling.
    
    Note: The Elixir container derives types from actual JSON values, not from 
    type annotations. So {"name": "string"} has type "string" (literal),
    while {"name": "Alice"} has inferred type "string" from the value.
    """

    def test_compile_returns_response_contract(self, base_url):
        """Test that compile endpoint returns response_contract."""
        prompt_content = """
init do
  @version: 1
end init

Answer the question.
response do
  {"name": "Alice", "age": 42}
end response
"""
        response = httpx.post(
            f"{base_url}/api/compile",
            json={"prompt": prompt_content, "params": {}},
            timeout=30.0,
        )
        
        assert response.status_code == 200
        data = response.json()
        
        assert "response_contract" in data
        contract = data["response_contract"]
        assert contract is not None
        assert contract["type"] == "object"
        assert "properties" in contract
        
        properties = contract["properties"]
        assert properties["name"]["type"] == "string"
        assert properties["age"]["type"] == "integer"

    def test_python_validate_response_with_contract(self, base_url):
        """Test that Python client can validate using contract from container."""
        from dotprompt.async_client import DotPromptAsyncClient
        import asyncio
        
        prompt_content = """
init do
  @version: 1
end init

Hello response.
response do
  {"greeting": "Hello", "count": 42}
end response
"""
        response = httpx.post(
            f"{base_url}/api/compile",
            json={"prompt": prompt_content, "params": {}},
            timeout=30.0,
        )
        
        assert response.status_code == 200
        data = response.json()
        contract = data["response_contract"]
        
        # Test valid response
        valid_response = {"greeting": "Hello", "count": 42}
        
        async def run_test():
            async with DotPromptAsyncClient(base_url=base_url) as client:
                result = await client.validate_response(valid_response, contract)
                return result
        
        result = asyncio.run(run_test())
        assert result is True
        
        # Test invalid response (wrong type)
        invalid_response = {"greeting": "Hello", "count": "not a number"}
        
        async def run_invalid():
            async with DotPromptAsyncClient(base_url=base_url) as client:
                result = await client.validate_response(invalid_response, contract)
                return result
        
        result = asyncio.run(run_invalid())
        assert result is False
        
        # Test missing field
        missing_field_response = {"greeting": "Hello"}
        
        async def run_missing():
            async with DotPromptAsyncClient(base_url=base_url) as client:
                result = await client.validate_response(missing_field_response, contract)
                return result
        
        result = asyncio.run(run_missing())
        assert result is False

    def test_contract_with_boolean_type(self, base_url):
        """Test contract with boolean field type."""
        prompt_content = """
init do
  @version: 1
end init

Is this valid?
response do
  {"valid": true, "reason": "test"}
end response
"""
        response = httpx.post(
            f"{base_url}/api/compile",
            json={"prompt": prompt_content, "params": {}},
            timeout=30.0,
        )
        
        assert response.status_code == 200
        data = response.json()
        contract = data["response_contract"]
        
        properties = contract["properties"]
        assert properties["valid"]["type"] == "boolean"
        
        from dotprompt.async_client import DotPromptAsyncClient
        import asyncio
        
        valid_response = {"valid": True, "reason": "test"}
        
        async def run_test():
            async with DotPromptAsyncClient(base_url=base_url) as client:
                return await client.validate_response(valid_response, contract)
        
        assert asyncio.run(run_test()) is True

    def test_contract_with_array_type(self, base_url):
        """Test contract with array field type."""
        prompt_content = """
init do
  @version: 1
end init

List items.
response do
  {"items": ["a", "b", "c"], "count": 3}
end response
"""
        response = httpx.post(
            f"{base_url}/api/compile",
            json={"prompt": prompt_content, "params": {}},
            timeout=30.0,
        )
        
        assert response.status_code == 200
        data = response.json()
        contract = data["response_contract"]
        
        properties = contract["properties"]
        assert properties["items"]["type"] == "array"
        
        from dotprompt.async_client import DotPromptAsyncClient
        import asyncio
        
        valid_response = {"items": ["a", "b", "c"], "count": 3}
        
        async def run_test():
            async with DotPromptAsyncClient(base_url=base_url) as client:
                return await client.validate_response(valid_response, contract)
        
        assert asyncio.run(run_test()) is True


class TestCompileEndpoint:
    """Test the compile endpoint directly."""

    def test_compile_with_seed(self, base_url):
        """Test compile with seed for reproducible vary."""
        prompt_content = """
init do
  @version: 1
  @color: vary[red, blue, green]
end init

The color is {color}.
"""
        response1 = httpx.post(
            f"{base_url}/api/compile",
            json={"prompt": prompt_content, "params": {}, "seed": 42},
            timeout=30.0,
        )
        
        response2 = httpx.post(
            f"{base_url}/api/compile",
            json={"prompt": prompt_content, "params": {}, "seed": 42},
            timeout=30.0,
        )
        
        assert response1.json()["vary_selections"] == response2.json()["vary_selections"]

    def test_compile_with_version(self, base_url):
        """Test compile with version."""
        prompt_content = """
init do
  @version: 1
end init

Version 1 content.
"""
        response = httpx.post(
            f"{base_url}/api/compile",
            json={"prompt": prompt_content, "params": {}, "version": 1},
            timeout=30.0,
        )
        
        assert response.status_code == 200
        data = response.json()
        assert data["version"] == 1


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
