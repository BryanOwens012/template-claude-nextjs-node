import { isRedisAvailable } from '@/services/redis.js';
import { isSupabaseAvailable } from '@/services/supabase.js';
import { createRouter, publicProcedure } from '@/trpc/init.js';
import { ApiInfoSchema } from '@/types/index.js';

export const infoRouter = createRouter({
  get: publicProcedure.output(ApiInfoSchema).query(() => {
    return {
      name: 'Express API Template',
      version: '1.0.0',
      description: 'Next.js + Node.js template API',
      status: (isRedisAvailable() && isSupabaseAvailable() ? 'operational' : 'degraded') as
        | 'operational'
        | 'degraded',
      timestamp: new Date().toISOString(),
    };
  }),
});
