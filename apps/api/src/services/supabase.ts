import type { Database } from '@shared/supabase/types.js';
import { createClient, type SupabaseClient } from '@supabase/supabase-js';
import { getEnvironment } from '@/config/environment.js';

let supabaseClient: SupabaseClient<Database> | null = null;
let supabaseAvailable = false;

export const initSupabase = async (): Promise<void> => {
  try {
    const env = getEnvironment();

    supabaseClient = createClient<Database>(env.SUPABASE_URL, env.SUPABASE_SECRET_KEY, {
      auth: {
        persistSession: false,
        autoRefreshToken: false,
      },
    });

    // Test connectivity. In a fresh template there are no tables yet,
    // so 42P01 (table not found) is expected and still confirms connectivity.
    const { error } = await supabaseClient.from('_health_check').select('id').limit(1);

    if (error && error.code !== '42P01') {
      console.warn(`⚠️  Supabase connection test failed: ${error.message}`);
      supabaseAvailable = false;
      return;
    }

    const hostname = new URL(env.SUPABASE_URL).hostname;
    console.log(`✅ Supabase connected (${hostname})`);
    supabaseAvailable = true;
  } catch (error) {
    console.warn(
      `⚠️  Supabase initialization failed: ${error instanceof Error ? error.message : String(error)}`,
    );
    supabaseAvailable = false;
  }
};

export const getSupabaseClient = (): SupabaseClient<Database> => {
  if (!supabaseClient) {
    throw new Error('Supabase client is not initialized. Call initSupabase() first.');
  }
  return supabaseClient;
};
export const isSupabaseAvailable = (): boolean => supabaseAvailable;
