import { config } from 'dotenv';
import { z } from 'zod';

config();

const EnvironmentSchema = z.object({
  PORT: z.coerce.number().default(8000),
  NODE_ENV: z.enum(['development', 'production', 'test']).default('development'),
  SUPABASE_URL: z.url(),
  SUPABASE_SECRET_KEY: z.string().min(1),
  REDIS_URL: z.url().default('redis://localhost:6379'),
  CORS_ORIGINS: z.string().default('http://localhost:3000'),
  OPENROUTER_API_KEY: z.string().optional(),
  // Override only to point the api at a proxy or a local stand-in; unset means openrouter.ai.
  OPENROUTER_BASE_URL: z.url().optional(),
  POSTHOG_API_KEY: z.string().optional(),
  POSTHOG_HOST: z.string().optional(),
  // One project-wide switch for LLM analytics redaction (never per call site). Default on:
  // PostHog keeps model, tokens, cost, and latency but not prompt or completion text.
  POSTHOG_LLM_PRIVACY_MODE: z
    .enum(['true', 'false'])
    .default('true')
    .transform((value) => value === 'true'),
  ADMIN_EMAIL_DOMAIN: z.string().optional(),
  INTERNAL_API_KEY: z.string().optional(),
  BYPASS_AUTH: z.string().optional().default('false'),
});

let environment: z.infer<typeof EnvironmentSchema> | null = null;

export const getEnvironment = () => {
  if (environment) {
    return environment;
  }

  const result = EnvironmentSchema.safeParse(process.env);

  if (!result.success) {
    console.error('❌ Environment validation failed:');
    result.error.issues.forEach((issue) => {
      console.error(`  ${issue.path.join('.')} — ${issue.code}: ${issue.message}`);
    });
    process.exit(1);
  }

  environment = result.data;
  return environment;
};

export const getCorsOrigins = (): string | string[] => {
  const env = getEnvironment();
  if (env.CORS_ORIGINS === '*') {
    return '*';
  }
  return env.CORS_ORIGINS.split(',').map((origin) => origin.trim());
};
