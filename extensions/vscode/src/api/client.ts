/**
 * Server API client for communicating with the dot-prompt Phoenix backend
 */

import * as vscode from 'vscode';
import {
  CompileRequest,
  CompileResponse,
  CompileError,
  RenderRequest,
  RenderResponse,
  ServerConfig,
  DEFAULT_CONFIG
} from './types';

/**
 * Get server configuration from VS Code settings
 */
function getServerConfig(): ServerConfig {
  const config = vscode.workspace.getConfiguration('dotPrompt');
  return {
    serverUrl: config.get<string>('serverUrl') || DEFAULT_CONFIG.serverUrl,
    timeout: config.get<number>('timeout') || DEFAULT_CONFIG.timeout
  };
}

/**
 * Create a standardized error message for API failures
 */
function createApiError(error: unknown, context: string): CompileError {
  if (error instanceof Error) {
    // Check for common error patterns
    if (error.message.includes('ECONNREFUSED') || error.message.includes('connect')) {
      return {
        error: 'server_unreachable',
        message: `Cannot connect to .prompt server at ${getServerConfig().serverUrl}. Is the server running?`
      };
    }
    if (error.message.includes('timeout')) {
      return {
        error: 'timeout',
        message: 'Request to server timed out'
      };
    }
    return {
      error: 'api_error',
      message: `${context}: ${error.message}`
    };
  }
  return {
    error: 'unknown',
    message: `${context}: Unknown error occurred`
  };
}

/**
 * Compile a .prompt file by calling the backend API
 */
export async function compile(
  prompt: string,
  params: Record<string, any> = {},
  options: { seed?: number; major?: number } = {}
): Promise<CompileResponse> {
  const config = getServerConfig();
  const request: CompileRequest = {
    prompt,
    params,
    ...options
  };

  try {
    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), config.timeout);

    const response = await fetch(`${config.serverUrl}/api/compile`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json'
      },
      body: JSON.stringify(request),
      signal: controller.signal
    });

    clearTimeout(timeoutId);

    if (!response.ok) {
      const errorData = await response.json().catch(() => ({})) as CompileError;
      const error = new Error(errorData.message || `Server returned ${response.status}`) as any;
      error.apiError = errorData;
      throw error;
    }

    const data = await response.json() as CompileResponse;
    return data;
  } catch (error) {
    if (error instanceof Error && error.name === 'AbortError') {
      throw createApiError(new Error('Request timed out'), 'compile');
    }
    throw createApiError(error, 'compile');
  }
}

/**
 * Render a compiled template with runtime parameters
 */
export async function render(
  template: string,
  params: Record<string, any> = {}
): Promise<RenderResponse> {
  const config = getServerConfig();
  const request: RenderRequest = {
    template,
    params
  };

  try {
    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), config.timeout);

    const response = await fetch(`${config.serverUrl}/api/render`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json'
      },
      body: JSON.stringify(request),
      signal: controller.signal
    });

    clearTimeout(timeoutId);

    if (!response.ok) {
      throw new Error(`Server returned ${response.status}`);
    }

    const data = await response.json() as RenderResponse;
    return data;
  } catch (error) {
    if (error instanceof Error && error.name === 'AbortError') {
      throw createApiError(new Error('Request timed out'), 'render');
    }
    throw createApiError(error, 'render');
  }
}

/**
 * Check if the server is reachable
 */
export async function checkServerConnection(): Promise<boolean> {
  const config = getServerConfig();
  try {
    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), 5000);

    const response = await fetch(`${config.serverUrl}/api/prompts`, {
      method: 'GET',
      signal: controller.signal
    });

    clearTimeout(timeoutId);
    return response.ok;
  } catch {
    return false;
  }
}

/**
 * Get the current server URL from settings
 */
export function getServerUrl(): string {
  return getServerConfig().serverUrl;
}
