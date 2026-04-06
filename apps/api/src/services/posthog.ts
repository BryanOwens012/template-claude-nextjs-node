import { PostHog } from 'posthog-node';
import { getEnvironment } from '@/config/environment.js';

let posthogClient: PostHog | null = null;

/**
 * Initialize the PostHog Node.js client singleton.
 * No-ops if POSTHOG_API_KEY is not configured.
 */
export const initPostHog = (): void => {
  const env = getEnvironment();

  if (!env.POSTHOG_API_KEY) {
    console.log('⚠️  PostHog: API key not configured — server-side analytics disabled');
    return;
  }

  posthogClient = new PostHog(env.POSTHOG_API_KEY, {
    host: env.POSTHOG_HOST ?? 'https://us.i.posthog.com',
  });

  console.log('✅ PostHog: Initialized');
};

/**
 * Get the PostHog client instance (may be null if not configured).
 */
export const getPostHog = (): PostHog | null => {
  return posthogClient;
};

/**
 * Capture a server-side event. No-ops if PostHog is not initialized.
 */
export const captureEvent = (
  distinctId: string,
  event: string,
  properties?: Record<string, unknown>,
): void => {
  if (!posthogClient) return;
  posthogClient.capture({ distinctId, event, properties });
};

/**
 * Shut down the PostHog client gracefully, flushing any queued events.
 */
export const shutdownPostHog = async (): Promise<void> => {
  if (!posthogClient) return;

  try {
    await posthogClient.shutdown();
    console.log('✅ PostHog: Shut down');
  } catch (error) {
    console.warn(
      '[PostHog] Shutdown error:',
      error instanceof Error ? error.message : String(error),
    );
  }
};
