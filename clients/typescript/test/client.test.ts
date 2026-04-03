import { describe, it, expect, vi, beforeEach } from 'vitest';
import { DotPromptClient } from '../src/client.js';

describe('DotPromptClient', () => {
    let client: DotPromptClient;

    beforeEach(() => {
        client = new DotPromptClient({
            baseUrl: 'http://test-server:4041',
            maxRetries: 0,
        });
        global.fetch = vi.fn();
    });

    it('should delegate listPrompts to asyncClient', async () => {
        (global.fetch as any).mockResolvedValueOnce({
            ok: true,
            json: () => Promise.resolve(['p1']),
        });

        const result = await client.listPrompts();
        expect(result).toEqual(['p1']);
    });

    it('should delegate compile to asyncClient', async () => {
        const mockResult = {
            template: 'Hello',
            cache_hit: false,
            compiled_tokens: 1,
            version: 1,
            warnings: [],
        };

        (global.fetch as any).mockResolvedValueOnce({
            ok: true,
            json: () => Promise.resolve(mockResult),
        });

        const result = await client.compile('test_prompt', { name: 'World' });
        expect(result).toEqual(mockResult);
    });
});
