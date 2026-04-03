import { z } from "zod";
import { type ResponseContract } from "./models.js";
import { ValidationError } from "./errors.js";

/**
 * Sleep for a specified number of milliseconds.
 */
export function sleep(ms: number): Promise<void> {
  return new Promise(resolve => setTimeout(resolve, ms));
}

/**
 * Validates a response object against a contract's field definitions.
 * Converts the contract's type strings to Zod schemas for runtime validation.
 *
 * @param response - The data to validate.
 * @param contract - The contract containing field definitions.
 * @returns boolean - true if valid, false if not valid.
 */
export function validateResponse(
  response: unknown,
  contract: ResponseContract
): boolean {
  // Allow null/undefined response for contracts without required fields
  if (response === null || response === undefined) {
    return true;
  }
  
  if (typeof response !== "object") {
    return false;
  }

  const schemaShape: Record<string, z.ZodTypeAny> = {};

  // Elixir returns contract with "properties" key, not "fields"
  // Properties format: { "name": { "type": "string", "required": true } }
  const properties = contract.properties || contract.fields || {};
  
  for (const [key, field] of Object.entries(properties)) {
    // field is an object with "type" property: { type: "string", required: true }
    const fieldType = typeof field === 'object' && field !== null 
      ? (field as any).type || 'string'
      : 'string';
    schemaShape[key] = mapTypeToZod(fieldType);
  }

  // Handle empty schema (no fields to validate)
  if (Object.keys(schemaShape).length === 0) {
    return true;
  }

  const schema = z.object(schemaShape);
  const result = schema.safeParse(response);

  // Return false instead of throwing on validation failure
  if (!result.success) {
    return false;
  }

  return true;
}

/**
 * Maps contract type strings to Zod types.
 *
 * @param type - The type string from the contract (e.g., 'string', 'number').
 * @returns z.ZodTypeAny
 */
function mapTypeToZod(type: string | undefined): z.ZodTypeAny {
  // Handle undefined or non-string types
  const safeType = typeof type === 'string' ? type.toLowerCase() : 'string';
  
  switch (safeType) {
    case "string":
      return z.string();
    case "number":
    case "float":
      return z.number();
    case "integer":
      return z.number().int();
    case "boolean":
      return z.boolean();
    case "array":
      return z.array(z.any());
    case "object":
      return z.record(z.any());
    case "null":
      return z.null();
    default:
      return z.any();
  }
}
