import { getEnvironment } from '@/config/environment.js';
import { getSupabaseClient, isSupabaseAvailable } from '@/services/supabase.js';
import { createRouter, publicProcedure } from '@/trpc/init.js';

export const supabaseRouter = createRouter({
  test: publicProcedure.query(() => {
    const supabase = getSupabaseClient();
    if (!supabase || !isSupabaseAvailable()) {
      return { supabaseAvailable: false, message: 'Supabase client not initialized' };
    }
    const env = getEnvironment();
    return {
      supabaseAvailable: true,
      message: 'Supabase client initialized successfully',
      url: env.SUPABASE_URL,
    };
  }),
});
