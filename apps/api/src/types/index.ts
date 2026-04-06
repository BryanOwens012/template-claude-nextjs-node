import { z } from 'zod';

export const HealthResponseSchema = z.object({
  status: z.enum(['healthy', 'degraded']),
  redis: z.string(),
  supabase: z.string(),
  langfuse: z.string().optional(),
  message: z.string(),
  timestamp: z.iso.datetime(),
});
export type HealthResponse = z.infer<typeof HealthResponseSchema>;

export const ApiInfoSchema = z.object({
  name: z.string(),
  version: z.string(),
  description: z.string(),
  status: z.enum(['operational', 'degraded']),
  timestamp: z.iso.datetime(),
});
export type ApiInfo = z.infer<typeof ApiInfoSchema>;

export const CacheTestResponseSchema = z.object({
  action: z.string(),
  key: z.string(),
  value: z.string().nullable(),
  cached: z.boolean(),
  redisAvailable: z.boolean(),
});
export type CacheTestResponse = z.infer<typeof CacheTestResponseSchema>;

export const SupabaseTestResponseSchema = z.object({
  supabaseAvailable: z.boolean(),
  message: z.string(),
  url: z.string().optional(),
});
export type SupabaseTestResponse = z.infer<typeof SupabaseTestResponseSchema>;

// --- tRPC input schemas ---

export const CacheSetInputSchema = z.object({
  key: z.string().min(1),
  value: z.string().min(1),
  ttl: z.number().int().positive().default(300),
});
export type CacheSetInput = z.infer<typeof CacheSetInputSchema>;

export const CacheKeyInputSchema = z.object({
  key: z.string().min(1),
});
export type CacheKeyInput = z.infer<typeof CacheKeyInputSchema>;

export const PromptInputSchema = z.object({
  name: z.string().min(1),
  variables: z.record(z.string(), z.string()).optional().default({}),
});
export type PromptInput = z.infer<typeof PromptInputSchema>;

export const TraceExampleInputSchema = z.object({
  prompt: z.string().optional().default("What's the weather like in San Francisco?"),
  sessionId: z.string().optional(),
});
export type TraceExampleInput = z.infer<typeof TraceExampleInputSchema>;
