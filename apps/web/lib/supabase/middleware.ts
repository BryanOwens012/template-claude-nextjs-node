import { type CookieOptions, createServerClient } from '@supabase/ssr';
import { type NextRequest, NextResponse } from 'next/server';
import { SUPABASE_COOKIE_DOMAIN } from './server';

const cookieDomainOption = SUPABASE_COOKIE_DOMAIN ? { domain: SUPABASE_COOKIE_DOMAIN } : {};

export const updateSession = async (request: NextRequest) => {
  const response = NextResponse.next({
    request: {
      headers: request.headers,
    },
  });

  try {
    const supabase = createServerClient(
      process.env.NEXT_PUBLIC_SUPABASE_URL || 'https://placeholder.supabase.co',
      process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY || 'placeholder-key',
      {
        cookies: {
          getAll() {
            return request.cookies.getAll();
          },
          setAll(cookiesToSet) {
            // Do NOT set httpOnly — the browser Supabase client (createBrowserClient)
            // needs document.cookie access for getSession(), signOut(), and token refresh.
            cookiesToSet.forEach(({ name, value, options }) => {
              response.cookies.set(name, value, {
                ...options,
                secure: true,
                sameSite: 'lax',
                ...cookieDomainOption,
              } as CookieOptions);
            });
          },
        },
      },
    );

    // Refresh token
    const {
      data: { user },
    } = await supabase.auth.getUser();

    return { response, user };
  } catch (error) {
    console.error('[updateSession] Error:', error);
    return { response, user: null };
  }
};
