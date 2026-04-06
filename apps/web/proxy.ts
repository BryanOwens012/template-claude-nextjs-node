import { type NextRequest, NextResponse } from 'next/server';
import { updateSession } from '@/lib/supabase/middleware';

const PROTECTED_ROUTES = ['/dashboard', '/update-password'];
const AUTH_ROUTES = ['/login', '/signup', '/reset-password'];

const hasSupabaseSession = (request: NextRequest): boolean => {
  return request.cookies.getAll().some(({ name }) => name.startsWith('sb-'));
};

const buildLoginRedirect = (request: NextRequest, pathname: string): NextResponse => {
  const loginUrl = new URL('/login', request.url);
  loginUrl.searchParams.set('redirect', pathname);
  return NextResponse.redirect(loginUrl);
};

const matchesRoutes = (pathname: string, routes: string[]): boolean => {
  return routes.some((route) => pathname.startsWith(route));
};

export const proxy = async (request: NextRequest) => {
  const { pathname } = request.nextUrl;
  const isProtectedRoute = matchesRoutes(pathname, PROTECTED_ROUTES);
  const isAuthRoute = matchesRoutes(pathname, AUTH_ROUTES);

  // No session cookies: skip Supabase call entirely
  if (!hasSupabaseSession(request)) {
    if (isProtectedRoute) {
      return buildLoginRedirect(request, pathname);
    }
    return NextResponse.next();
  }

  // Has session cookies: validate with Supabase
  try {
    const { response, user } = await updateSession(request);

    if (!user) {
      if (isProtectedRoute) {
        return buildLoginRedirect(request, pathname);
      }
      return response;
    }

    // Authenticated user on landing page or auth pages -> /dashboard
    if (pathname === '/' || isAuthRoute) {
      return NextResponse.redirect(new URL('/dashboard', request.url));
    }

    return response;
  } catch (error) {
    console.error('[Proxy] Error:', error);
    if (isProtectedRoute) {
      return buildLoginRedirect(request, pathname);
    }
    return NextResponse.next();
  }
};

export const config = {
  matcher: [
    /*
     * Match all paths except static assets and images.
     */
    '/((?!_next/static|_next/image|favicon.ico|.*\\.(?:svg|png|jpg|jpeg|gif|webp)$).*)',
  ],
};
