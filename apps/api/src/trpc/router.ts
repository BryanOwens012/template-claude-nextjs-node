import { createRouter } from '@/trpc/init.js';
import { healthRouter } from '@/trpc/routers/health.js';
import { infoRouter } from '@/trpc/routers/info.js';
import { llmRouter } from '@/trpc/routers/llm.js';
import { redisRouter } from '@/trpc/routers/redis.js';
import { supabaseRouter } from '@/trpc/routers/supabase.js';

export const appRouter = createRouter({
  health: healthRouter,
  info: infoRouter,
  llm: llmRouter,
  redis: redisRouter,
  supabase: supabaseRouter,
});

export type AppRouter = typeof appRouter;
