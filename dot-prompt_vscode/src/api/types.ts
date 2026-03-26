/**
 * API response types for the dot-prompt server
 */

export interface CompileResponse {
  template: string;
  cache_hit: boolean;
  compiled_tokens: number;
  vary_selections: Record<string, string | { id: string; text: string }>;
  response_contract: ResponseContract | null;
  warnings: string[];
  params?: Record<string, ParamMeta>;
  major?: number;
  version?: number | string;
}

export interface ParamMeta {
  type: string;
  default?: any;
  values?: string[];
  range?: number[];
  doc?: string;
  itemType?: string; // For list types, the type of items in the list
}

export interface ResponseContract {
  type: string;
  schema?: object;
  json_schema?: object;
  description?: string;
}

export interface CompileRequest {
  prompt: string;
  params: Record<string, any>;
  seed?: number;
  major?: number;
}

export interface RenderResponse {
  rendered: string;
  tokens: number;
}

export interface RenderRequest {
  template: string;
  params: Record<string, any>;
}

export interface CompileError {
  error: string;
  message: string;
  line?: number;
  column?: number;
}

export interface ServerConfig {
  serverUrl: string;
  timeout: number;
}

export const DEFAULT_CONFIG: ServerConfig = {
  serverUrl: 'http://localhost:4000',
  timeout: 30000
};
