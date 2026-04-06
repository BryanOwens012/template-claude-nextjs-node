import { timingSafeEqual } from 'node:crypto';
import { TRPCError } from '@trpc/server';
import { getEnvironment } from '../config/environment.js';
import { getSupabaseClient } from '../services/supabase.js';
import { middleware, publicProcedure } from './init.js';

export interface AuthUser {
  id: string;
  email: string;
  isAdmin: boolean;
  firstName?: string;
  lastName?: string;
  displayName?: string;
}

const safeCompareKeys = (a: string, b: string): boolean => {
  try {
    return timingSafeEqual(Buffer.from(a), Buffer.from(b));
  } catch {
    return false;
  }
};

const isAdminEmail = (email: string): boolean => {
  if (!email) return false;
  const env = getEnvironment();
  const domain = env.ADMIN_EMAIL_DOMAIN;
  if (!domain) return false;
  const atIndex = email.lastIndexOf('@');
  return atIndex !== -1 && email.slice(atIndex + 1).toLowerCase() === domain.toLowerCase();
};

/**
 * Extract Supabase auth token from cookie header.
 * Matches any Supabase project's auth token cookies (sb-*-auth-token),
 * excluding code-verifier variants.
 */
const extractTokenFromCookies = (cookieHeader: string | undefined): string | undefined => {
  if (!cookieHeader) return undefined;

  const cookies = cookieHeader.split(';').map((c) => c.trim());
  const tokenPattern = /^sb-.*-auth-token(\.\d+)?$/;

  const authTokenParts: string[] = [];

  for (const cookie of cookies) {
    const name = cookie.split('=')[0];
    if (tokenPattern.test(name)) {
      const [, value] = cookie.split('=');
      if (value) {
        authTokenParts.push(value);
      }
    }
  }

  if (authTokenParts.length > 0) {
    const fullValue = authTokenParts.join('');
    try {
      const decoded = decodeURIComponent(fullValue);
      const tokens = JSON.parse(decoded);
      if (Array.isArray(tokens) && tokens[0]) {
        return tokens[0];
      }
    } catch {
      return fullValue;
    }
  }

  return undefined;
};

/**
 * Resolve user from auth sources. Order:
 * 1. Dev bypass (BYPASS_AUTH=true, non-production only)
 * 2. Internal service bypass (x-internal-api-key header)
 * 3. Authorization Bearer header
 * 4. Cookie fallback
 */
const resolveUser = async (
  req: { headers: Record<string, string | string[] | undefined> },
  required: boolean,
): Promise<AuthUser | undefined> => {
  const env = getEnvironment();

  // 1. Development bypass (never active in production)
  if (env.BYPASS_AUTH === 'true' && env.NODE_ENV !== 'production') {
    const devEmail = 'dev@localhost';
    return {
      id: '00000000-0000-0000-0000-000000000000',
      email: devEmail,
      isAdmin: isAdminEmail(devEmail),
    };
  }

  // 2. Internal service bypass (server-to-server calls)
  const internalKey = req.headers['x-internal-api-key'];
  if (
    env.INTERNAL_API_KEY &&
    typeof internalKey === 'string' &&
    safeCompareKeys(internalKey, env.INTERNAL_API_KEY)
  ) {
    return {
      id: '00000000-0000-0000-0000-000000000001',
      email: 'internal-service@localhost',
      isAdmin: false,
    };
  }

  let token: string | undefined;
  // biome-ignore lint/suspicious/noExplicitAny: Supabase types are complex
  let user: any;
  // biome-ignore lint/suspicious/noExplicitAny: Supabase types are complex
  let error: any;
  const supabase = getSupabaseClient();

  // 3. Try Authorization header first
  const authHeader = req.headers.authorization;
  if (authHeader && typeof authHeader === 'string' && authHeader.startsWith('Bearer ')) {
    token = authHeader.slice(7);
    const result = await supabase.auth.getUser(token);
    user = result.data.user;
    error = result.error;
  }

  // 4. Fallback to session cookies
  if (!user && !error) {
    const cookieHeader = typeof req.headers.cookie === 'string' ? req.headers.cookie : undefined;
    token = extractTokenFromCookies(cookieHeader);
    if (token) {
      const result = await supabase.auth.getUser(token);
      user = result.data.user;
      error = result.error;
    }
  }

  if (error || !user) {
    if (required) {
      throw new TRPCError({
        code: 'UNAUTHORIZED',
        message: 'Missing or invalid Authorization header',
      });
    }
    return undefined;
  }

  const email = user.email ?? '';
  const meta = user.user_metadata ?? {};

  return {
    id: user.id,
    email,
    isAdmin: isAdminEmail(email),
    firstName: meta.first_name || undefined,
    lastName: meta.last_name || undefined,
    displayName: meta.display_name || meta.full_name || meta.name || undefined,
  };
};

// --- Auth middleware ---

const isAuthenticated = middleware(async ({ ctx, next }) => {
  const user = await resolveUser(ctx.req, true);
  return next({ ctx: { ...ctx, user: user as AuthUser } });
});

const isOptionalAuth = middleware(async ({ ctx, next }) => {
  const user = await resolveUser(ctx.req, false);
  return next({ ctx: { ...ctx, user } });
});

const isAdmin = middleware(async ({ ctx, next }) => {
  const user = (ctx as { user?: AuthUser }).user;
  if (!user?.isAdmin) {
    throw new TRPCError({
      code: 'FORBIDDEN',
      message: 'Admin access required',
    });
  }
  return next();
});

const isAdminOrInternal = middleware(async ({ ctx, next }) => {
  const env = getEnvironment();
  const internalKey = ctx.req.headers['x-internal-api-key'];
  if (
    env.INTERNAL_API_KEY &&
    typeof internalKey === 'string' &&
    safeCompareKeys(internalKey, env.INTERNAL_API_KEY)
  ) {
    return next();
  }

  const user = (ctx as { user?: AuthUser }).user;
  if (user?.isAdmin) {
    return next();
  }

  throw new TRPCError({
    code: 'FORBIDDEN',
    message: 'Admin or internal service access required',
  });
});

// --- Procedure builders ---

/** Requires valid JWT. ctx.user is always defined. */
export const authenticatedProcedure = publicProcedure.use(isAuthenticated);

/** Optional JWT. ctx.user may be undefined. */
export const optionalAuthProcedure = publicProcedure.use(isOptionalAuth);

/** Requires valid JWT + admin email. */
export const adminProcedure = authenticatedProcedure.use(isAdmin);

/** Requires optional auth + (admin OR internal API key). */
export const adminOrInternalProcedure = optionalAuthProcedure.use(isAdminOrInternal);
