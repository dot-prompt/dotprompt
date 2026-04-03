/**
 * Base class for all dot-prompt errors.
 */
export class DotPromptError extends Error {
  constructor(message: string) {
    super(message);
    this.name = this.constructor.name;
    Object.setPrototypeOf(this, new.target.prototype);
  }
}

/**
 * Errors related to network/connection.
 */
export class ConnectionError extends DotPromptError {}

/**
 * Request timeout errors.
 */
export class TimeoutError extends DotPromptError {}

/**
 * Errors returned by the dot-prompt server (5xx).
 */
export class ServerError extends DotPromptError {
  constructor(public statusCode: number, message: string) {
    super(`Server Error (${statusCode}): ${message}`);
  }
}

/**
 * Base for client-side API errors (4xx).
 */
export class APIClientError extends DotPromptError {
  constructor(public statusCode: number, message: string) {
    super(`API Client Error (${statusCode}): ${message}`);
  }
}

/**
 * Specific error when required parameters are missing.
 */
export class MissingRequiredParamsError extends APIClientError {}

/**
 * Error when a prompt or resource is not found (404).
 */
export class PromptNotFoundError extends APIClientError {}

/**
 * Validation errors for requests or responses.
 */
export class ValidationError extends APIClientError {}
