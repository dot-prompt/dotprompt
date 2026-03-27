/**
 * Integration tests for TypeScript client against live container.
 * 
 * These tests require DOT_PROMPT_URL environment variable to point to a running
 * dot-prompt container.
 * 
 * Run with: DOT_PROMPT_URL=http://localhost:4000 npm test
 */

import { describe, it, expect, beforeAll } from 'vitest';
import { DotPromptClient } from '../src/client.js';
import { DotPromptAsyncClient } from '../src/asyncClient.js';

const baseUrl = process.env.DOT_PROMPT_URL || 'http://localhost:4000';

const isConfigured = baseUrl.startsWith('http://') || baseUrl.startsWith('https://');

const testIf = (condition: boolean) => condition ? describe : describe.skip;

testIf(isConfigured)('Contract Integration Tests', () => {
    let client: DotPromptClient;
    let asyncClient: DotPromptAsyncClient;

    beforeAll(() => {
        client = new DotPromptClient({ baseUrl });
        asyncClient = new DotPromptAsyncClient({ baseUrl });
    });

    it('should compile and return response_contract', async () => {
        const promptContent = `
init do
  @version: 1
end init

Answer the question.
response do
  {"name": "Alice", "age": 42}
end response
`;
        const result = await client.compile(promptContent, {});

        expect(result.response_contract).toBeDefined();
        expect(result.response_contract?.type).toBe('object');
        expect(result.response_contract?.properties).toBeDefined();

        const properties = result.response_contract!.properties!;
        expect(properties.name.type).toBe('string');
        expect(properties.age.type).toBe('integer');
    });

    it('should validate responses against contract from container', async () => {
        const promptContent = `
init do
  @version: 1
end init

Hello response.
response do
  {"greeting": "Hello", "count": 42}
end response
`;
        const result = await client.compile(promptContent, {});
        const contract = result.response_contract!;

        // Test valid response
        const validResponse = { greeting: 'Hello', count: 42 };
        expect(client.validateResponse(validResponse, contract)).toBe(true);

        // Test invalid response (wrong type)
        const invalidResponse = { greeting: 'Hello', count: 'not a number' };
        expect(client.validateResponse(invalidResponse, contract)).toBe(false);

        // Test missing field
        const missingFieldResponse = { greeting: 'Hello' };
        expect(client.validateResponse(missingFieldResponse, contract)).toBe(false);
    });

    it('should handle boolean type in contracts', async () => {
        const promptContent = `
init do
  @version: 1
end init

Is this valid?
response do
  {"valid": true, "reason": "test"}
end response
`;
        const result = await client.compile(promptContent, {});
        const contract = result.response_contract!;

        expect(contract.properties?.valid.type).toBe('boolean');

        const validResponse = { valid: true, reason: 'test' };
        expect(client.validateResponse(validResponse, contract)).toBe(true);
    });

    it('should handle array type in contracts', async () => {
        const promptContent = `
init do
  @version: 1
end init

List items.
response do
  {"items": ["a", "b", "c"], "count": 3}
end response
`;
        const result = await client.compile(promptContent, {});
        const contract = result.response_contract!;

        expect(contract.properties?.items.type).toBe('array');

        const validResponse = { items: ['a', 'b', 'c'], count: 3 };
        expect(client.validateResponse(validResponse, contract)).toBe(true);
    });

    it('should handle nested objects in contracts', async () => {
        const promptContent = `
init do
  @version: 1
end init

User info.
response do
  {"user": {"name": "Alice"}, "score": 100}
end response
`;
        const result = await client.compile(promptContent, {});
        const contract = result.response_contract!;

        expect(contract.properties?.user.type).toBe('object');

        const validResponse = { user: { name: 'Alice' }, score: 100 };
        expect(client.validateResponse(validResponse, contract)).toBe(true);
    });

    it('should compile with seed for reproducible vary', async () => {
        const promptContent = `
init do
  @version: 1
  @color: vary[red, blue, green]
end init

The color is {color}.
`;
        const result1 = await client.compile(promptContent, {}, { seed: 42 });
        const result2 = await client.compile(promptContent, {}, { seed: 42 });

        expect(result1.vary_selections).toEqual(result2.vary_selections);
    });

    it('should compile with major version', async () => {
        const promptContent = `
init do
  @version: 1
end init

Version 1 content.
`;
        const result = await client.compile(promptContent, {}, { major: 1 });

        expect(result.major).toBe(1);
    });
});

testIf(isConfigured)('Async Client Integration', () => {
    let client: DotPromptAsyncClient;

    beforeAll(() => {
        client = new DotPromptAsyncClient({ baseUrl });
    });

    it('should use async compile method', async () => {
        const promptContent = `
init do
  @version: 1
end init

Test response.
response do
  {"status": "ok"}
end response
`;
        const result = await client.compile(promptContent, {});

        expect(result.template).toBeDefined();
        expect(result.response_contract).toBeDefined();
    });

    it('should use async validateResponse method', async () => {
        const promptContent = `
init do
  @version: 1
end init

Test.
response do
  {"field": "value"}
end response
`;
        const compileResult = await client.compile(promptContent, {});
        const contract = compileResult.response_contract!;

        const validResponse = { field: 'value' };
        const result = client.validateResponse(validResponse, contract);

        expect(result).toBe(true);
    });
});
