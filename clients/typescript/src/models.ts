import { z } from "zod";

/**
 * Field specification in a response contract.
 */
export const ContractField = z.object({
  type: z.string(),
  required: z.boolean().optional(),
  default: z.any().optional(),
});
export type ContractField = z.infer<typeof ContractField>;

/**
 * Zod schema for a response contract.
 * Note: Elixir returns "properties" not "fields"
 */
export const ResponseContract = z.object({
  type: z.string().optional(),
  properties: z.record(ContractField).optional(),
  fields: z.record(ContractField).optional(),
  compatible: z.boolean().optional(),
});
export type ResponseContract = z.infer<typeof ResponseContract>;

/**
 * Zod schema for a prompt schema.
 */
export const PromptSchema = z.object({
  name: z.string(),
  version: z.number(),
  description: z.string().optional(),
  mode: z.string().optional(),
  docs: z.string().optional(),
  params: z.record(z.any()),
  fragments: z.record(z.any()),
  contract: ResponseContract.optional(),
});
export type PromptSchema = z.infer<typeof PromptSchema>;

/**
 * Zod schema for compilation result.
 * Note: response_contract can be null when no response block is defined
 */
export const CompileResult = z.object({
  template: z.string(),
  cache_hit: z.boolean(),
  compiled_tokens: z.number(),
  vary_selections: z.record(z.any()).optional(),
  response_contract: z.union([ResponseContract, z.null()]).optional(),
  version: z.number().optional(),
  major: z.number().optional(),
  params: z.record(z.any()).optional(),
  warnings: z.array(z.string()).default([]),
});
export type CompileResult = z.infer<typeof CompileResult>;

/**
 * Zod schema for rendering result.
 */
export const RenderResult = z.object({
  prompt: z.string(),
  response_contract: z.union([ResponseContract, z.null()]).optional(),
  cache_hit: z.boolean(),
  compiled_tokens: z.number(),
  injected_tokens: z.number(),
  vary_selections: z.record(z.any()).optional(),
});
export type RenderResult = z.infer<typeof RenderResult>;

/**
 * Zod schema for injection result.
 */
export const InjectResult = z.object({
  prompt: z.string(),
  injected_tokens: z.number(),
});
export type InjectResult = z.infer<typeof InjectResult>;

/**
 * Event types for SSE stream.
 */
export const DotPromptEvent = z.discriminatedUnion("type", [
  z.object({ type: z.literal("breaking_change"), timestamp: z.number(), payload: z.any() }),
  z.object({ type: z.literal("versioned"), timestamp: z.number(), payload: z.any() }),
  z.object({ type: z.literal("committed"), timestamp: z.number(), payload: z.any() }),
  z.object({ type: z.literal("file_change"), prompt: z.string() }),
  z.object({ type: z.literal("connected") }),
]);
export type DotPromptEvent = z.infer<typeof DotPromptEvent>;
