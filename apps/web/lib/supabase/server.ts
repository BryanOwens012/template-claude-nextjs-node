import { type CookieOptions, createServerClient } from '@supabase/ssr';
import { cookies } from 'next/headers';

/** Optional cookie domain for cross-subdomain setups (e.g. .myapp.com) */
export const SUPABASE_COOKIE_DOMAIN = process.env.SUPABASE_COOKIE_DOMAIN ?? '';

const cookieDomainOption = SUPABASE_COOKIE_DOMAIN ? { domain: SUPABASE_COOKIE_DOMAIN } : {};

export const createClient = async () => {
  const cookieStore = await cookies();

  return createServerClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL || 'https://placeholder.supabase.co',
    process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY || 'placeholder-key',
    {
      cookies: {
        getAll() {
          return cookieStore.getAll();
        },
        setAll(cookiesToSet) {
          try {
            // Do NOT set httpOnly — the browser Supabase client (createBrowserClient)
            // needs document.cookie access for getSession(), signOut(), and token refresh.
            cookiesToSet.forEach(({ name, value, options }) => {
              cookieStore.set(name, value, {
                ...options,
                secure: true,
                sameSite: 'lax',
                ...cookieDomainOption,
              } as CookieOptions);
            });
          } catch {
            // The `setAll` method was called from a Server Component.
            // This can be ignored if you have middleware handling cookie updates.
          }
        },
      },
    },
  );
};
