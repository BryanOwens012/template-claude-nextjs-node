import { createClient } from '@supabase/supabase-js';

/**
 * Server-only Supabase client using secret key.
 * ONLY use this in Server Actions and Route Handlers.
 * NEVER expose SUPABASE_SECRET_KEY in client-side code.
 */
export const createServiceClient = () => {
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const secretKey = process.env.SUPABASE_SECRET_KEY;

  if (!url || !secretKey) {
    throw new Error(
      'Missing NEXT_PUBLIC_SUPABASE_URL or SUPABASE_SECRET_KEY environment variables',
    );
  }

  return createClient(url, secretKey, {
    auth: {
      autoRefreshToken: false,
      persistSession: false,
    },
  });
};
