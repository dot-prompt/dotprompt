import { describe, it, expect, vi, beforeEach } from 'vitest';
import { DotPromptAsyncClient } from '../src/asyncClient.js';
import { ConnectionError } from '../src/errors.js';

describe('DotPromptAsyncClient', () => {
  let client: DotPromptAsyncClient;

  beforeEach(() => {
    client = new DotPromptAsyncClient({
      baseUrl: 'http://test-server:4041',
      maxRetries: 0, // Disable retries for testing failures
    });
    // Mock global fetch
    global.fetch = vi.fn();
  });

  it('should list prompts', async () => {
    (global.fetch as any).mockResolvedValueOnce({
      ok: true,
      json: () => Promise.resolve(['prompt1', 'prompt2']),
    });

    const prompts = await client.listPrompts();
    expect(prompts).toEqual(['prompt1', 'prompt2']);
    expect(global.fetch).toHaveBeenCalledWith('http://test-server:4041/api/prompts', expect.any(Object));
  });

  it('should handle connection errors', async () => {
    (global.fetch as any).mockRejectedValueOnce(new Error('fetch failed'));

    await expect(client.listPrompts()).rejects.toThrow(ConnectionError);
  });

  it('should compile a prompt', async () => {
    const mockResult = {
      template: 'Hello {{name}}',
      cache_hit: false,
      compiled_tokens: 10,
      version: 1,
      warnings: [],
    };

    (global.fetch as any).mockResolvedValueOnce({
      ok: true,
      json: () => Promise.resolve(mockResult),
    });

    const result = await client.compile('test_prompt', { name: 'World' });
    expect(result).toEqual(mockResult);
    expect(global.fetch).toHaveBeenCalledWith(
        'http://test-server:4041/api/compile', 
        expect.objectContaining({
            method: 'POST',
            body: JSON.stringify({
                prompt: 'test_prompt',
                params: { name: 'World' },
                seed: undefined,
                major: undefined
            })
        })
    );
  });
});
