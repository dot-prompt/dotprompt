

## Package Metadata (Updated)

* **Name**: dot-prompt
* **Version**: 0.1.0
* **Description**: Python client for the dot-prompt container API
* **Author**: dot-prompt team
* **License**: Apache 2.0 ✅ (updated from MIT)
* **Python Version**: 3.9+

---

## API Endpoints

| Endpoint                       | Method | Purpose                         |
| ------------------------------ | ------ | ------------------------------- |
| `/api/prompts`                 | GET    | List all available prompts      |
| `/api/collections`             | GET    | List prompt collections         |
| `/api/schema/:prompt`          | GET    | Get latest schema               |
| `/api/schema/:prompt/:version` | GET    | Get schema for specific version |
| `/api/compile`                 | POST   | Compile prompt                  |
| `/api/render`                  | POST   | Compile + inject runtime        |
| `/api/inject`                  | POST   | Inject runtime                  |
| `/api/version`                 | POST   | Version actions (future)        |
| `/api/events`                  | GET    | SSE event stream                |

---

## Package Structure (Updated)

```
dot-prompt-python-client/
├── pyproject.toml
├── src/dotprompt/
│   ├── __init__.py
│   ├── client.py
│   ├── async_client.py
│   ├── _transport.py
│   ├── models.py
│   ├── exceptions.py
│   └── events.py          # SSE streaming + event types
├── tests/
│   ├── test_client.py
│   └── test_async_client.py
└── README.md
```

---

## Core Design Principles

* Async-first architecture (httpx)
* Sync wrapper over async client
* Private transport layer (`_Transport`)
* Strict Pydantic v2 validation
* Versioned prompt system (`version`, not `major`)
* Contract-aware prompt validation

---

## 1. Async Client

### Constructor

```python
DotPromptAsyncClient(
    base_url: str = "http://localhost:4041",
    timeout: float = 30.0,
    verify_ssl: bool = True,
    api_key: str | None = None,  # future cloud feature (stub)
    max_retries: int = 3
)
```

---

### Methods

#### Prompt Discovery

```python
async def list_prompts() -> list[str]
async def list_collections() -> list[str]
```

---

#### Schema

```python
async def get_schema(
    prompt: str,
    version: int | None = None
) -> PromptSchema
```

---

#### Compile

```python
async def compile(
    prompt: str,
    params: dict,
    seed: int | None = None,
    version: int | None = None
) -> CompileResult
```

---

#### Render

```python
async def render(
    prompt: str,
    params: dict,
    runtime: dict,
    seed: int | None = None,
    version: int | None = None
) -> RenderResult
```

---

#### Inject

```python
async def inject(template: str, runtime: dict) -> InjectResult
```

---

#### SSE Events (NEW)

```python
async def events(self) -> AsyncIterator[Event]:
    """
    Streams real-time container events:
    - breaking_change
    - versioned
    - committed
    """
```

Uses `httpx` streaming internally.

---

#### Response Validation (NEW)

```python
async def validate_response(
    self,
    response: dict,
    contract: dict
) -> bool:
    """
    Validates an LLM response against a prompt's response contract.
    Pure client-side validation (no API call).
    """
```

---

## 2. Sync Client

```python
DotPromptClient
```

* Thin wrapper around `DotPromptAsyncClient`
* Uses `asyncio.run()` internally
* Provides identical API surface

---

## 3. Transport Layer (`_Transport`)

Responsibilities:

* HTTP connection pooling (httpx)
* Retries with exponential backoff
* Timeout handling
* Request/response logging hooks
* API key header injection (future-ready)

---

## 4. Pydantic Models (Updated)

---

### ParamSpec

```python
class ParamSpec(BaseModel):
    type: str
    lifecycle: str | None = None
    doc: str | None = None
    default: Any | None = None
    values: list[Any] | None = None
    range: tuple | None = None
```

---

### FragmentSpec

```python
class FragmentSpec(BaseModel):
    type: str
    doc: str | None = None
    from_path: str | None = None
```

---

### Response Contract (NEW)

```python
class ContractField(BaseModel):
    type: str
    doc: str | None = None


class ResponseContract(BaseModel):
    fields: dict[str, ContractField]
    compatible: bool
```

---

### PromptSchema (UPDATED)

```python
class PromptSchema(BaseModel):
    name: str
    version: int
    description: str | None = None
    mode: str | None = None
    docs: str | None = None
    params: dict[str, ParamSpec]
    fragments: dict[str, FragmentSpec]
    contract: ResponseContract | None = None
```

---

### CompileResult (UPDATED)

```python
class CompileResult(BaseModel):
    template: str
    cache_hit: bool
    compiled_tokens: int
    vary_selections: dict | None = None
    response_contract: dict | None = None
    version: int
    warnings: list[str] = []
```

---

### RenderResult

```python
class RenderResult(BaseModel):
    prompt: str
    response_contract: dict | None = None
    cache_hit: bool
    compiled_tokens: int
    injected_tokens: int
    vary_selections: dict | None = None
```

---

### InjectResult

```python
class InjectResult(BaseModel):
    prompt: str
    injected_tokens: int
```

---

## 5. Event System (`events.py`) (NEW)

Defines SSE event types:

```python
class Event(BaseModel):
    type: str
    timestamp: float
    payload: dict
```

Event types:

* `breaking_change`
* `versioned`
* `committed`

---

## 6. Error Handling

### Base

```python
DotPromptError
```

### Categories

* `ConnectionError`
* `TimeoutError`
* `ServerError` (5xx)
* `APIClientError` (4xx)

  * `MissingRequiredParamsError`
  * `PromptNotFoundError`
  * `ValidationError`

---

## 7. Configuration

### Environment Variables

| Variable            | Purpose                   |
| ------------------- | ------------------------- |
| `DOTPROMPT_URL`     | Base API URL              |
| `DOTPROMPT_TIMEOUT` | Request timeout           |
| `DOTPROMPT_API_KEY` | Future auth system (stub) |

---

## 8. Dependencies

### Required

* `httpx>=0.24.0`
* `pydantic>=2.0.0`

### Dev

* `pytest`
* `pytest-asyncio`
* `pytest-mock`
* `ruff`
* `mypy`

---

## 9. Key Design Rules (Confirmed)

* Async-first architecture
* Sync wrapper is convenience only
* `_Transport` is private and handles all HTTP
* All API responses validated via Pydantic
* Versioning uses `version` (NOT `major`)
* Response contracts are first-class citizens
* SSE is optional but included in v1 client
* No redundant echo fields in responses (e.g., removed `params` from `CompileResult`)

---

## 10. Acceptance Criteria (Updated)

1. Async client connects to `http://localhost:4041`
2. Sync wrapper works for all async methods
3. All endpoints implemented (including `/schema/:version`)
4. SSE event stream functional via `events()`
5. Response models fully validated via Pydantic v2
6. Errors map correctly to exception hierarchy
7. `validate_response()` correctly checks contract compliance
8. Package installs via `pip install dot-prompt`
9. Unit tests pass with mocked HTTP responses
