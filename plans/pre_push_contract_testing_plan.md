# Pre-Push Contract Testing Plan

## Overview

This plan establishes a comprehensive pre-push testing pipeline that validates contract consistency across all three dot-prompt components before every `git push`.

## Components Under Test

1. **Elixir Container** (`dot_prompt/`) - Phoenix application
2. **Python Client** (`dot-prompt-python-client/`) - HTTP client library
3. **TypeScript Client** (`dot-prompt-ts/`) - HTTP client library

## What are "Contracts"?

Contracts in dot-prompt refer to **response schemas** defined in prompt files:

```
response do
  {"name": "string", "age": "integer"}
end response
```

The system must:
1. Parse these response blocks in the Elixir container
2. Generate JSON Schema from them
3. Return the schema via the compile API
4. Allow Python/TypeScript clients to validate responses against the schema

## Testing Strategy

### Phase 1: Elixir Container Tests
- Run existing unit tests in `apps/dot_prompt/test/`
- Key test file: `apps/dot_prompt/test/dot_prompt/contract_test.exs`
- Tests validate: parsing, schema derivation, schema comparison

### Phase 2: Container API Test
- Start the container via docker-compose
- Verify the compile endpoint returns proper `response_contract`
- Test endpoint: `POST /api/compile`

### Phase 3: Python Client Integration Tests
- Run pytest with live container
- Test `validate_response()` function with contracts from API
- Verify schema consistency between Elixir and Python

### Phase 4: TypeScript Client Integration Tests
- Run vitest with live container
- Test `validateResponse()` function with contracts from API
- Verify schema consistency between Elixir and TypeScript

## Implementation Files

| File | Purpose |
|------|---------|
| `.git/hooks/pre-push` | Git hook that triggers tests |
| `scripts/test_contracts.sh` | Main test orchestration script |
| `scripts/wait_for_container.sh` | Health check helper |
| `dot-prompt-python-client/tests/test_integration.py` | Python container integration tests |
| `dot-prompt-ts/test/integration.test.ts` | TypeScript container integration tests |

## Test Workflow

```
git push
    │
    ▼
pre-push hook triggered
    │
    ├── 1. Build & start Docker container
    ├── 2. Wait for container health
    ├── 3. Run Elixir tests (mix test)
    ├── 4. Run Python integration tests
    ├── 5. Run TypeScript integration tests
    ├── 6. Stop container
    │
    ▼
push proceeds / rejected
```

## Environment Variables

| Variable | Default | Purpose |
|----------|---------|---------|
| `DOT_PROMPT_PORT` | 4000 | Container port |
| `DOT_PROMPT_URL` | http://localhost:4000 | Full URL for clients |
| `PROMPT_DIR_HOST` | ./prompts | Prompt files directory |

## Acceptance Criteria

1. Pre-push hook is executable and triggers on `git push`
2. Elixir tests pass including contract_test.exs
3. Container starts and responds to /api/compile
4. Python client can compile prompts and validate contracts
5. TypeScript client can compile prompts and validate contracts
6. All tests run in under 5 minutes
7. Container is cleaned up after tests

## Skipping Tests

To skip pre-push tests temporarily:
```bash
git push --no-verify
```
