import { describe, it, expect, vi, beforeEach } from 'vitest';
import { Transport } from '../src/transport.js';
import { ServerError } from '../src/errors.js';

describe('Transport', () => {
    it('should retry on 500 error', async () => {
        const transport = new Transport({
            baseUrl: 'http://test-server:4041',
            maxRetries: 2,
        });

        global.fetch = vi.fn()
            .mockResolvedValueOnce({
                ok: false,
                status: 500,
                json: () => Promise.resolve({ error: 'Server Down' }),
            })
            .mockResolvedValueOnce({
                ok: true,
                status: 200,
                json: () => Promise.resolve({ success: true }),
            });

        const result = await transport.request('/api/test');
        expect(result).toEqual({ success: true });
        expect(global.fetch).toHaveBeenCalledTimes(2);
    });

    it('should fail after max retries', async () => {
        const transport = new Transport({
            baseUrl: 'http://test-server:4041',
            maxRetries: 1,
        });

        global.fetch = vi.fn()
            .mockResolvedValue({
                ok: false,
                status: 500,
                json: () => Promise.resolve({ error: 'Persistent Fail' }),
            });

        await expect(transport.request('/api/test')).rejects.toThrow(ServerError);
        expect(global.fetch).toHaveBeenCalledTimes(2);
    });
});
