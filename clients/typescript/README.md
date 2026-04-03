# dot-prompt-ts

TypeScript client for the [dot-prompt](https://github.com/dot-prompt) container API.

## Features

- **Async-first API**: Primary client designed for modern TS/JS environments.
- **Strong runtime validation**: Every response is validated using **Zod**.
- **SSE streaming**: Native async generator for server-sent events.
- **Contract-aware validation**: Validate LLM responses against prompt contracts.
- **Node-friendly**: Built-in support for Node.js 18+ with zero external fetch dependencies.

## Installation

```bash
npm install dot-prompt
```

## Usage

### Basic Example

```ts
import { DotPromptClient } from 'dot-prompt';

const client = new DotPromptClient({
  baseUrl: 'http://localhost:4041',
  timeout: 5000,
});

const result = await client.compile('my_prompt', {
  name: 'World',
});

console.log(result.template);
```

### Full Render (Compile + Inject)

```ts
const result = await client.render('my_prompt', {
  name: 'World',
}, {
  user_id: '123',
});

console.log(result.prompt);
```

### SSE Events

```ts
for await (const event of client.events()) {
  if (event.type === 'committed') {
    console.log('Prompt committed:', event.payload);
  }
}
```

### Contract Validation

```ts
const isValid = client.validateResponse(
  { score: 10, explain: "Good" },
  { 
    fields: { 
      score: { type: "number" }, 
      explain: { type: "string" } 
    }, 
    compatible: true 
  }
);
```

## API

### Constructor `DotPromptAsyncClient` / `DotPromptClient`

- `baseUrl`: Default `http://localhost:4041` (env: `DOTPROMPT_URL`)
- `apiKey`: Optional API key (env: `DOTPROMPT_API_KEY`)
- `timeout`: Request timeout in ms (env: `DOTPROMPT_TIMEOUT`)
- `maxRetries`: Maximum retry attempts for failed requests.

### Methods

- `listPrompts()`: List all available prompts.
- `listCollections()`: List all prompt collections.
- `getSchema(prompt: string, version?: number)`: Get prompt metadata and parameter schema.
- `compile(prompt, params, options)`: Prepare a prompt template.
- `render(prompt, params, runtime, options)`: Full template preparation + data injection.
- `inject(template, runtime)`: Inject runtime data into a raw template string.
- `validateResponse(response, contract)`: Validate data against a response contract.
- `events()`: Access the SSE stream as an async generator.

## Error Handling

- `ConnectionError`: Network or server reachability issues.
- `TimeoutError`: Request timed out.
- `PromptNotFoundError`: 404 from the server.
- `APIClientError`: Other 4xx client errors.
- `ServerError`: 5xx server errors.
- `ValidationError`: Zod or contract validation failures.

## License

Apache 2.0
