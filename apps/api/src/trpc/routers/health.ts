import { getEnvironment } from '@/config/environment.js';
import { getPostHog } from '@/services/posthog.js';
import { getRedisClient } from '@/services/redis.js';
import { getSupabaseClient } from '@/services/supabase.js';
import { createRouter, publicProcedure } from '@/trpc/init.js';
import { HealthResponseSchema } from '@/types/index.js';

export const healthRouter = createRouter({
  check: publicProcedure.output(HealthResponseSchema).query(async () => {
    let redisStatus = 'unavailable';
    let supabaseStatus = 'unavailable';

    // Redis check
    const redis = getRedisClient();
    if (redis) {
      try {
        await redis.ping();
        redisStatus = 'connected';
      } catch (error) {
        redisStatus = `error: ${error instanceof Error ? error.message : String(error)}`;
      }
    }

    // Supabase check
    const supabase = getSupabaseClient();
    if (supabase) {
      try {
        const { error } = await supabase.from('_health_check').select('id').limit(1);
        // 42P01 = table not found; still means the connection is working
        supabaseStatus = !error || error.code === '42P01' ? 'connected' : 'initialized';
      } catch {
        supabaseStatus = 'initialized';
      }
    }

    // PostHog and OpenRouter: configuration only. A health probe must not send events or
    // spend against the key, so neither makes a request; llm.traceExample is the live check.
    const posthogStatus = getPostHog() ? 'configured' : 'unconfigured';
    const openrouterStatus = getEnvironment().OPENROUTER_API_KEY ? 'configured' : 'unconfigured';

    const connected: string[] = [];
    if (redisStatus === 'connected') {
      connected.push('Redis');
    }
    if (supabaseStatus === 'connected') {
      connected.push('Supabase');
    }

    const isHealthy = redisStatus === 'connected' || supabaseStatus === 'connected';

    return {
      status: isHealthy ? ('healthy' as const) : ('degraded' as const),
      redis: redisStatus,
      supabase: supabaseStatus,
      posthog: posthogStatus,
      openrouter: openrouterStatus,
      message:
        connected.length > 0
          ? `API is running with ${connected.join(', ')}`
          : 'API is running (no services connected)',
      timestamp: new Date().toISOString(),
    };
  }),
});
