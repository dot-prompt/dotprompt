# dot-prompt TypeScript Client Package Plan

## Overview

Create `dot-prompt` — a TypeScript client library for interacting with the dot-prompt Phoenix container API.

It provides:

* Async-first API (primary)
* Sync-friendly wrapper (Node-only convenience)
* Strong runtime validation (Zod)
* SSE event streaming
* Prompt compilation + rendering + validation

---

## Package Metadata (Updated)

* **Name**: dot-prompt
* **Version**: 0.1.0
* **Description**: TypeScript client for the dot-prompt container API
* **License**: Apache 2.0
* **Runtime**: Node.js 18+
* **Language**: TypeScript 5+

---

## API Endpoints

| Endpoint                       | Method | Purpose                  |
| ------------------------------ | ------ | ------------------------ |
| `/api/prompts`                 | GET    | List prompts             |
| `/api/collections`             | GET    | List collections         |
| `/api/schema/:prompt`          | GET    | Get latest schema        |
| `/api/schema/:prompt/:version` | GET    | Get versioned schema     |
| `/api/compile`                 | POST   | Compile prompt           |
| `/api/render`                  | POST   | Compile + inject runtime |
| `/api/inject`                  | POST   | Inject runtime           |
| `/api/version`                 | POST   | Version actions (future) |
| `/api/events`                  | GET    | SSE event stream         |

---

## Package Structure

```
dot-prompt-ts/
├── package.json
├── tsconfig.json
├── src/
│   ├── index.ts
│   ├── client.ts              # DotPromptClient (sync wrapper)
│   ├── asyncClient.ts         # DotPromptAsyncClient (primary)
│   ├── transport.ts           # HTTP layer (undici/fetch wrapper)
│   ├── models.ts              # Types + Zod schemas
│   ├── errors.ts              # Error hierarchy
│   ├── events.ts              # SSE stream + event types
│   └── utils.ts
├── test/
│   ├── client.test.ts
│   └── asyncClient.test.ts
└── README.md
```

---

## Core Design Principles

* Async-first architecture
* Sync wrapper built on async client
* Strong runtime validation via Zod
* Native fetch / undici (no axios dependency)
* SSE streaming via `EventSource` or `fetch streaming`
* Versioning uses `version` (NOT `major`)
* Contract-aware response validation

---

## 1. Async Client (Primary API)

### Constructor

```ts
class DotPromptAsyncClient {
  constructor(options: {
    baseUrl?: string; // default http://localhost:4041
    timeout?: number;
    apiKey?: string;
    maxRetries?: number;
  })
}
```

---

### Methods

#### Prompt discovery

```ts
listPrompts(): Promise<string[]>
listCollections(): Promise<string[]>
```

---

#### Schema

```ts
getSchema(prompt: string, version?: number): Promise<PromptSchema>
```

---

#### Compile

```ts
compile(
  prompt: string,
  params: Record<string, any>,
  options?: {
    seed?: number;
    version?: number;
  }
): Promise<CompileResult>
```

---

#### Render

```ts
render(
  prompt: string,
  params: Record<string, any>,
  runtime: Record<string, any>,
  options?: {
    seed?: number;
    version?: number;
  }
): Promise<RenderResult>
```

---

#### Inject

```ts
inject(template: string, runtime: Record<string, any>): Promise<InjectResult>
```

---

## 2. SSE Event Stream (NEW)

```ts
events(): AsyncGenerator<DotPromptEvent>
```

### Implementation options:

* Node 18+: `fetch` streaming + NDJSON parser
* or `eventsource-parser`

### Event types:

```ts
type DotPromptEvent =
  | { type: "breaking_change"; timestamp: number; payload: any }
  | { type: "versioned"; timestamp: number; payload: any }
  | { type: "committed"; timestamp: number; payload: any };
```

---

## 3. Response Validation (NEW)

```ts
validateResponse(
  response: unknown,
  contract: ResponseContract
): boolean
```

Uses Zod schema generated from contract definition.

---

## 4. Sync Client Wrapper

```ts
class DotPromptClient {
  private asyncClient: DotPromptAsyncClient;
}
```

Wraps async methods using:

```ts
await this.asyncClient.compile(...)
```

Executed via:

* `async/await` + internal promise bridge

---

## 5. Transport Layer (`transport.ts`)

Responsibilities:

* HTTP requests via native `fetch`
* Retry with exponential backoff
* Timeout handling via AbortController
* API key injection
* Logging hooks (optional)

---

## 6. Types + Zod Models

---

### ParamSpec

```ts
export const ParamSpec = z.object({
  type: z.string(),
  lifecycle: z.string().optional(),
  doc: z.string().optional(),
  default: z.any().optional(),
  values: z.array(z.any()).optional(),
  range: z.tuple([z.any(), z.any()]).optional(),
});
```

---

### FragmentSpec

```ts
export const FragmentSpec = z.object({
  type: z.string(),
  doc: z.string().optional(),
  from_path: z.string().optional(),
});
```

---

### Response Contract (NEW)

```ts
export const ContractField = z.object({
  type: z.string(),
  doc: z.string().optional(),
});

export const ResponseContract = z.object({
  fields: z.record(ContractField),
  compatible: z.boolean(),
});
```

---

### PromptSchema (UPDATED)

```ts
export const PromptSchema = z.object({
  name: z.string(),
  version: z.number(),
  description: z.string().optional(),
  mode: z.string().optional(),
  docs: z.string().optional(),
  params: z.record(ParamSpec),
  fragments: z.record(FragmentSpec),
  contract: ResponseContract.optional(),
});
```

---

### CompileResult (UPDATED)

```ts
export const CompileResult = z.object({
  template: z.string(),
  cache_hit: z.boolean(),
  compiled_tokens: z.number(),
  vary_selections: z.record(z.any()).optional(),
  response_contract: z.record(z.any()).optional(),
  version: z.number(),
  warnings: z.array(z.string()).default([]),
});
```

---

### RenderResult

```ts
export const RenderResult = z.object({
  prompt: z.string(),
  response_contract: z.record(z.any()).optional(),
  cache_hit: z.boolean(),
  compiled_tokens: z.number(),
  injected_tokens: z.number(),
  vary_selections: z.record(z.any()).optional(),
});
```

---

### InjectResult

```ts
export const InjectResult = z.object({
  prompt: z.string(),
  injected_tokens: z.number(),
});
```

---

## 7. Error Handling

```ts
class DotPromptError extends Error {}
class ConnectionError extends DotPromptError {}
class TimeoutError extends DotPromptError {}
class ServerError extends DotPromptError {}
class APIClientError extends DotPromptError {}

class MissingRequiredParamsError extends APIClientError {}
class PromptNotFoundError extends APIClientError {}
class ValidationError extends APIClientError {}
```

---

## 8. Configuration

### Environment Variables

| Variable            | Purpose            |
| ------------------- | ------------------ |
| `DOTPROMPT_URL`     | Base URL           |
| `DOTPROMPT_TIMEOUT` | Request timeout    |
| `DOTPROMPT_API_KEY` | Future auth (stub) |

---

## 9. Dependencies

### Runtime

* None (native fetch + Web APIs)
* Optional: `eventsource-parser` (SSE)

### Dev

* `typescript`
* `tsup` (build)
* `zod`
* `vitest`
* `eslint`
* `prettier`

---

## 10. Key Design Rules (Updated)

* Async-first core client
* Sync wrapper is convenience only
* Native fetch (no axios)
* Zod replaces Pydantic
* Versioning uses `version` (NOT `major`)
* SSE streaming included in v1
* Contract validation is first-class
* Transport layer is isolated

---

## 11. Acceptance Criteria

1. Connects to `http://localhost:4041`
2. Async client fully functional
3. Sync wrapper works in Node
4. All endpoints implemented
5. SSE stream works via `events()`
6. Zod validation enforced for all responses
7. `validateResponse()` works with contracts
8. Proper error mapping for HTTP failures
9. Package builds via `tsup`
10. Tests pass with mocked fetch
