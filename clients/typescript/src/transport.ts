import { 
  ConnectionError, 
  TimeoutError, 
  ServerError, 
  APIClientError, 
  PromptNotFoundError,
  DotPromptError 
} from "./errors.js";
import { sleep } from "./utils.js";

/**
 * Options for a single HTTP request.
 */
export interface RequestOptions {
  method?: "GET" | "POST" | "PUT" | "DELETE";
  headers?: Record<string, string>;
  body?: any;
  timeout?: number;
}

/**
 * Transport layer for dot-prompt API requests.
 */
export class Transport {
  public baseUrl: string;
  public apiKey?: string;
  public timeout: number;
  public maxRetries: number;

  constructor(options: {
    baseUrl?: string;
    apiKey?: string;
    timeout?: number;
    maxRetries?: number;
  } = {}) {
    this.baseUrl = options.baseUrl || "http://localhost:4041";
    this.apiKey = options.apiKey;
    this.timeout = options.timeout || 30000; // default 30s
    this.maxRetries = options.maxRetries !== undefined ? options.maxRetries : 3;
  }

  /**
   * Helper to perform a request with retry logic.
   *
   * @param path - The API path (e.g. '/api/prompts').
   * @param options - Request options.
   * @returns T - The parsed JSON response.
   */
  public async request<T = any>(
    path: string, 
    options: RequestOptions = {}
  ): Promise<T> {
    let lastError: Error | null = null;

    for (let attempt = 0; attempt <= this.maxRetries; attempt++) {
      try {
        if (attempt > 0) {
          // Exponential backoff: 200ms, 400ms, 800ms...
          await sleep(Math.pow(2, attempt) * 100);
        }

        return await this._doRequest<T>(path, options);

      } catch (error: any) {
        lastError = error;

        // Don't retry client-side errors (4xx) or PromptNotFoundError
        if (error instanceof APIClientError) {
          throw error;
        }

        // Retry on 5xx or ConnectionError/TimeoutError
        if (attempt === this.maxRetries) {
          throw error;
        }
      }
    }

    throw lastError || new DotPromptError("Request failed after retries");
  }

  /**
   * Internal fetch wrapper.
   *
   * @param path - The API path.
   * @param options - Request options.
   * @returns T - The parsed JSON response.
   */
  private async _doRequest<T>(
    path: string, 
    options: RequestOptions = {}
  ): Promise<T> {
    const url = `${this.baseUrl}${path}`;
    const controller = new AbortController();
    const id = setTimeout(() => controller.abort(), options.timeout || this.timeout);

    const headers: Record<string, string> = {
      "Content-Type": "application/json",
      ...options.headers,
    };

    if (this.apiKey) {
      headers["Authorization"] = `Bearer ${this.apiKey}`;
    }

    try {
      const response = await fetch(url, {
        method: options.method || "GET",
        headers,
        body: options.body ? JSON.stringify(options.body) : undefined,
        signal: controller.signal,
      });

      clearTimeout(id);

      if (!response.ok) {
        return this._handleError(response);
      }

      return (await response.json()) as T;

    } catch (error: any) {
      clearTimeout(id);

      if (error.name === "AbortError") {
        throw new TimeoutError("Request timed out");
      }

      if (error.code === "ECONNREFUSED" || error.message.includes("fetch failed")) {
        throw new ConnectionError(`Could not connect to dot-prompt server at ${this.baseUrl}: ${error.message}`);
      }

      throw error;
    }
  }

  /**
   * Internal error mapper for HTTP responses.
   *
   * @param response - The Fetch API response object.
   */
  private async _handleError(response: Response): Promise<never> {
    const status = response.status;
    let message = "Unknown error";
    
    try {
      const body = await response.json();
      message = body.error || body.message || message;
    } catch {
      // Body not JSON, potentially raw text
      try {
        message = await response.text() || message;
      } catch {
        // Fallback to defaults
      }
    }

    if (status === 404) {
      throw new PromptNotFoundError(status, message);
    }

    if (status >= 500) {
      throw new ServerError(status, message);
    }

    throw new APIClientError(status, message);
  }
}
