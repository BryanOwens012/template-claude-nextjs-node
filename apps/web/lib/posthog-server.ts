import { PostHog } from 'posthog-node';

/**
 * Lazy PostHog server-side client for API routes and server actions.
 * Returns a no-op stub if NEXT_PUBLIC_POSTHOG_KEY is not configured,
 * so callers can always call .capture() without null checks.
 */

let client: PostHog | null = null;

const noopClient = {
  capture: () => {},
  shutdown: async () => {},
} as unknown as PostHog;

const getPostHogServer = (): PostHog => {
  if (client) return client;

  const posthogKey = process.env.NEXT_PUBLIC_POSTHOG_KEY;
  if (!posthogKey) return noopClient;

  const posthogHost = process.env.NEXT_PUBLIC_POSTHOG_HOST || undefined;
  client = new PostHog(posthogKey, { host: posthogHost });
  return client;
};

export const posthogServer = new Proxy({} as PostHog, {
  get: (_target, prop: string) => {
    const instance = getPostHogServer();
    const value = instance[prop as keyof PostHog];
    if (typeof value === 'function') {
      return value.bind(instance);
    }
    return value;
  },
});
