import { createBrowserClient } from '@supabase/ssr';

// Placeholder values allow the build to succeed without env vars set.
// At runtime, the real values from NEXT_PUBLIC_* will be used.
const SUPABASE_URL = process.env.NEXT_PUBLIC_SUPABASE_URL || 'https://placeholder.supabase.co';
const SUPABASE_KEY = process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY || 'placeholder-key';

export const createClient = () =>
  createBrowserClient(SUPABASE_URL, SUPABASE_KEY, {
    auth: {
      autoRefreshToken: true,
      persistSession: true,
      detectSessionInUrl: false,
    },
  });
