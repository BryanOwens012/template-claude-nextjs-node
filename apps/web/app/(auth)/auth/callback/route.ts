import { type CookieOptions, createServerClient } from '@supabase/ssr';
import { cookies } from 'next/headers';
import { type NextRequest, NextResponse } from 'next/server';
import { isEmailInvited } from '@/lib/supabase/check-invite';
import { SUPABASE_COOKIE_DOMAIN } from '@/lib/supabase/server';
import { createServiceClient } from '@/lib/supabase/service';

const cookieDomainOption = SUPABASE_COOKIE_DOMAIN ? { domain: SUPABASE_COOKIE_DOMAIN } : {};

export const GET = async (request: NextRequest) => {
  const requestUrl = new URL(request.url);
  const code = requestUrl.searchParams.get('code');
  const error = requestUrl.searchParams.get('error');
  const errorDescription = requestUrl.searchParams.get('error_description');

  // Handle OAuth errors
  if (error) {
    return NextResponse.redirect(
      new URL(
        `/auth/auth-code-error?error=${encodeURIComponent(error)}&error_description=${encodeURIComponent(errorDescription ?? '')}`,
        requestUrl.origin,
      ),
    );
  }

  if (code) {
    const cookieStore = await cookies();
    const supabase = createServerClient(
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

    try {
      const { error: exchangeError, data } = await supabase.auth.exchangeCodeForSession(code);

      if (exchangeError) {
        return NextResponse.redirect(
          new URL(
            `/auth/auth-code-error?error=exchange_failed&error_description=${encodeURIComponent(
              exchangeError.message,
            )}`,
            requestUrl.origin,
          ),
        );
      }

      // Check if user's email is invited
      if (data.user?.email) {
        const invited = await isEmailInvited(data.user.email);

        if (!invited) {
          // 1. Sign out the user to invalidate the session server-side
          await supabase.auth.signOut();

          // 2. Delete the user account using admin API
          const adminClient = createServiceClient();
          const { error: deleteError } = await adminClient.auth.admin.deleteUser(data.user.id);

          if (deleteError) {
            console.error(
              `Failed to delete unauthorized user ${data.user.email} (${data.user.id}):`,
              deleteError,
            );
          } else {
            console.log(`Deleted unauthorized user: ${data.user.email} (${data.user.id})`);
          }

          // 3. Redirect to error page and clear ALL Supabase cookies
          const errorUrl = new URL(
            `/auth/auth-code-error?error=not_invited&error_description=${encodeURIComponent(
              'This email has not been invited.',
            )}`,
            requestUrl.origin,
          );
          const response = NextResponse.redirect(errorUrl);

          const allCookies = cookieStore.getAll();
          for (const cookie of allCookies) {
            if (cookie.name.startsWith('sb-')) {
              response.cookies.set(cookie.name, '', {
                maxAge: 0,
                secure: true,
                sameSite: 'lax',
                ...cookieDomainOption,
              });
            }
          }

          return response;
        }
      }

      // Password recovery flow -> update-password page; everything else -> dashboard
      const type = requestUrl.searchParams.get('type');
      const destination = type === 'recovery' ? '/update-password' : '/dashboard';
      return NextResponse.redirect(new URL(destination, requestUrl.origin));
    } catch (exchangeError) {
      const errorMessage = exchangeError instanceof Error ? exchangeError.message : 'Unknown error';
      return NextResponse.redirect(
        new URL(
          `/auth/auth-code-error?error=exchange_failed&error_description=${encodeURIComponent(
            errorMessage,
          )}`,
          requestUrl.origin,
        ),
      );
    }
  }
};
