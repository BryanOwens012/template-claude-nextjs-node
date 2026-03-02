import { Router } from 'express';
import { isRedisAvailable } from '@/services/redis.js';
import { isSupabaseAvailable } from '@/services/supabase.js';
import { ApiInfoSchema } from '@/types/index.js';

const router = Router();

router.get('/', (_req, res) => {
  try {
    const apiInfo = {
      name: 'Express API Template',
      version: '1.0.0',
      description: 'Next.js + Node.js template API',
      status: isRedisAvailable() && isSupabaseAvailable() ? 'operational' : 'degraded',
      timestamp: new Date().toISOString(),
    };
    const validated = ApiInfoSchema.parse(apiInfo);
    res.json(validated);
  } catch (error) {
    console.error('[GET /] Error:', error);
    res.status(500).json({ error: 'Failed to generate API info' });
  }
});

export default router;
