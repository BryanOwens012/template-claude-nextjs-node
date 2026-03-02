import { z } from 'zod';

// Matches the HealthResponse interface in apps/web/components/ApiStatus.tsx exactly
export const HealthResponseSchema = z.object({
  status: z.enum(['healthy', 'degraded']),
  redis: z.string(),
  supabase: z.string(),
  langfuse: z.string().optional(),
  message: z.string(),
  timestamp: z.string().datetime(),
});
export type HealthResponse = z.infer<typeof HealthResponseSchema>;

export const ApiInfoSchema = z.object({
  name: z.string(),
  version: z.string(),
  description: z.string(),
  status: z.enum(['operational', 'degraded']),
  timestamp: z.string().datetime(),
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
