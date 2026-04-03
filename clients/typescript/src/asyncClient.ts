import { Transport } from "./transport.js";
import { 
  PromptSchema, 
  CompileResult, 
  RenderResult, 
  InjectResult, 
  type DotPromptEvent,
  ResponseContract
} from "./models.js";
import { validateResponse as _validateResponse } from "./utils.js";
import { createEventStream } from "./events.js";

/**
 * Options for creating a DotPromptAsyncClient.
 */
export interface DotPromptClientOptions {
  baseUrl?: string; // default http://localhost:4041
  timeout?: number;
  apiKey?: string;
  maxRetries?: number;
}

/**
 * Async-first client for Interacting with the dot-prompt container API.
 */
export class DotPromptAsyncClient {
  private transport: Transport;

  constructor(options: DotPromptClientOptions = {}) {
    this.transport = new Transport({
      baseUrl: options.baseUrl || process.env.DOTPROMPT_URL,
      apiKey: options.apiKey || process.env.DOTPROMPT_API_KEY,
      timeout: options.timeout !== undefined ? options.timeout : (process.env.DOTPROMPT_TIMEOUT ? parseInt(process.env.DOTPROMPT_TIMEOUT) : 30000),
      maxRetries: options.maxRetries !== undefined ? options.maxRetries : 3,
    });
  }

  /**
   * Lists all available prompts.
   * 
   * @returns Promise<string[]> - A list of prompt names.
   */
  public async listPrompts(): Promise<string[]> {
    return this.transport.request<string[]>("/api/prompts");
  }

  /**
   * Lists all available prompt collections.
   * 
   * @returns Promise<string[]> - A list of collection names.
   */
  public async listCollections(): Promise<string[]> {
    return this.transport.request<string[]>("/api/collections");
  }

  /**
   * Retrieves the schema for a specific prompt.
   * 
   * @param prompt - The name of the prompt.
   * @param major - Optional major version number.
   * @returns Promise<PromptSchema> - The validated prompt schema.
   */
  public async getSchema(prompt: string, major?: number): Promise<PromptSchema> {
    const path = major 
      ? `/api/schema/${prompt}/${major}` 
      : `/api/schema/${prompt}`;
    
    const data = await this.transport.request(path);
    return PromptSchema.parse(data);
  }

  /**
   * Compiles a prompt with the given parameters.
   * 
   * @param prompt - The name of the prompt.
   * @param params - The input data for compilation.
   * @param options - Optional seed and major version filters.
   * @returns Promise<CompileResult> - The compilation result.
   */
  public async compile(
    prompt: string,
    params: Record<string, any>,
    options: { seed?: number; major?: number } = {}
  ): Promise<CompileResult> {
    const data = await this.transport.request("/api/compile", {
      method: "POST",
      body: { 
        prompt: prompt, 
        params, 
        seed: options.seed, 
        major: options.major 
      },
    });
    return CompileResult.parse(data);
  }

  /**
   * Compiles and renders a prompt by injecting runtime data.
   * 
   * @param prompt - The name of the prompt.
   * @param params - The input data for compilation.
   * @param runtime - The runtime data for rendering.
   * @param options - Optional seed and major version filters.
   * @returns Promise<RenderResult> - The rendering result.
   */
  public async render(
    prompt: string,
    params: Record<string, any>,
    runtime: Record<string, any>,
    options: { seed?: number; major?: number } = {}
  ): Promise<RenderResult> {
    const data = await this.transport.request("/api/render", {
      method: "POST",
      body: { 
        prompt: prompt, 
        params, 
        runtime, 
        seed: options.seed, 
        major: options.major 
      },
    });
    return RenderResult.parse(data);
  }

  /**
   * Injects runtime data into a prompt template.
   * 
   * @param template - The template string to inject into.
   * @param runtime - The runtime data for injection.
   * @returns Promise<InjectResult> - The injection result.
   */
  public async inject(
    template: string, 
    runtime: Record<string, any>
  ): Promise<InjectResult> {
    const data = await this.transport.request("/api/inject", {
      method: "POST",
      body: { template, runtime },
    });
    return InjectResult.parse(data);
  }

  /**
   * Validates a response object against a contract.
   * 
   * @param response - The data to validate.
   * @param contract - The contract containing field definitions.
   * @returns boolean - true if valid, throws ValidationError if not.
   */
  public validateResponse(response: unknown, contract: ResponseContract): boolean {
    return _validateResponse(response, contract);
  }

  /**
   * Returns an async generator for receiving SSE events from the server.
   * 
   * @returns AsyncGenerator<DotPromptEvent>
   */
  public events(): AsyncGenerator<DotPromptEvent> {
    const url = `${this.transport.baseUrl}/api/events`;
    return createEventStream(url, this.transport.apiKey);
  }
}
