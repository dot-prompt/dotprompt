import { DotPromptAsyncClient, type DotPromptClientOptions } from "./asyncClient.js";
import { 
  PromptSchema, 
  CompileResult, 
  RenderResult, 
  InjectResult, 
  type DotPromptEvent,
  ResponseContract
} from "./models.js";

/**
 * Node-friendly companion client for dot-prompt.
 * Provides a simplified interface and potential future sync blocking capabilities.
 * For now, mostly delegates to the async client but remains the primary high-level interface.
 */
export class DotPromptClient {
  private asyncClient: DotPromptAsyncClient;

  constructor(options: DotPromptClientOptions = {}) {
    this.asyncClient = new DotPromptAsyncClient(options);
  }

  public async listPrompts(): Promise<string[]> {
    return this.asyncClient.listPrompts();
  }

  public async listCollections(): Promise<string[]> {
    return this.asyncClient.listCollections();
  }

  public async getSchema(prompt: string, version?: number): Promise<PromptSchema> {
    return this.asyncClient.getSchema(prompt, version);
  }

  public async compile(
    prompt: string,
    params: Record<string, any>,
    options: { seed?: number; version?: number } = {}
  ): Promise<CompileResult> {
    return this.asyncClient.compile(prompt, params, options);
  }

  public async render(
    prompt: string,
    params: Record<string, any>,
    runtime: Record<string, any>,
    options: { seed?: number; version?: number } = {}
  ): Promise<RenderResult> {
    return this.asyncClient.render(prompt, params, runtime, options);
  }

  public async inject(
    template: string, 
    runtime: Record<string, any>
  ): Promise<InjectResult> {
    return this.asyncClient.inject(template, runtime);
  }

  public validateResponse(response: unknown, contract: ResponseContract): boolean {
    return this.asyncClient.validateResponse(response, contract);
  }

  /**
   * SSE event stream getter.
   */
  public get events(): AsyncGenerator<DotPromptEvent> {
    return this.asyncClient.events();
  }
}
