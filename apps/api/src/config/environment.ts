import { config } from "dotenv";
import { z } from "zod";

config();

const EnvironmentSchema = z.object({
  PORT: z.coerce.number().default(8000),
  NODE_ENV: z.enum(["development", "production", "test"]).default("development"),
  SUPABASE_URL: z.string().url(),
  SUPABASE_SERVICE_ROLE_KEY: z.string().min(1),
  REDIS_URL: z.string().url().default("redis://localhost:6379"),
  CORS_ORIGINS: z.string().default("http://localhost:3000"),
  LANGFUSE_PUBLIC_KEY: z.string().optional(),
  LANGFUSE_SECRET_KEY: z.string().optional(),
  LANGFUSE_BASE_URL: z.string().url().optional(),
  ANTHROPIC_API_KEY: z.string().optional(),
});

let environment: z.infer<typeof EnvironmentSchema> | null = null;

export const getEnvironment = () => {
  if (environment) return environment;

  const result = EnvironmentSchema.safeParse(process.env);

  if (!result.success) {
    console.error("❌ Environment validation failed:");
    result.error.issues.forEach((issue) => {
      console.error(`  ${issue.path.join(".")} — ${issue.code}: ${issue.message}`);
    });
    process.exit(1);
  }

  environment = result.data;
  return environment;
};

export const getCorsOrigins = (): string | string[] => {
  const env = getEnvironment();
  if (env.CORS_ORIGINS === "*") return "*";
  return env.CORS_ORIGINS.split(",").map((origin) => origin.trim());
};
