# dot-prompt Python Client

Python client library for the dot-prompt container API.

## Installation

```bash
pip install dot-prompt
```

## Quick Start

### Synchronous Client

```python
from dotprompt import DotPromptClient

with DotPromptClient() as client:
    prompts = client.list_prompts()
    print(prompts)

    result = client.compile("my_prompt", params={"name": "world"})
    print(result.template)
```

### Async Client

```python
import asyncio
from dotprompt import DotPromptAsyncClient

async def main():
    async with DotPromptAsyncClient() as client:
        prompts = await client.list_prompts()
        print(prompts)

        result = await client.compile("my_prompt", params={"name": "world"})
        print(result.template)

asyncio.run(main())
```

## API Reference

### DotPromptClient

Synchronous client wrapper.

- `list_prompts()` - List all available prompts
- `list_collections()` - List root-level collections
- `get_schema(prompt)` - Get prompt schema
- `compile(prompt, params, seed=None, version=None)` - Compile a prompt
- `render(prompt, params, runtime=None, seed=None, version=None)` - Render a prompt
- `inject(template, runtime)` - Inject runtime into template
- `events()` - Stream real-time events
- `validate_response(response, contract)` - Validate response against contract

### DotPromptAsyncClient

Async client with the same methods as above but async.

## Configuration

```python
client = DotPromptClient(
    base_url="http://localhost:4041",  # container URL
    timeout=30.0,
    verify_ssl=True,
    api_key="your-api-key",  # optional
    max_retries=3,
)
```

## Models

- `PromptSchema` - Prompt metadata
- `CompileResult` - Compile operation result
- `RenderResult` - Render operation result
- `InjectResult` - Inject operation result
- `ResponseContract` - Response contract definition

## Exceptions

- `DotPromptError` - Base exception
- `ConnectionError` - Connection failed
- `TimeoutError` - Request timed out
- `PromptNotFoundError` - Prompt not found
- `ValidationError` - Validation failed
- `ServerError` - Server error (5xx)