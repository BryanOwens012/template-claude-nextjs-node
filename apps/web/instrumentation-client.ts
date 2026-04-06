import posthog from 'posthog-js';

// The date passed to `defaults` is the PostHog SDK defaults snapshot date.
// It pins the recommended configuration to the settings that were current as of
// that release. See: https://posthog.com/docs/libraries/js#sdk-defaults
const POSTHOG_DEFAULTS_DATE = '2026-01-30';

// Guard: read PostHog env vars directly so a misconfigured optional var
// never throws and crashes the client bundle (which would silently prevent
// React from hydrating and stop all API queries from running).
const posthogKey = process.env.NEXT_PUBLIC_POSTHOG_KEY;

// Recommended: set NEXT_PUBLIC_POSTHOG_HOST to a reverse proxy on your own subdomain
// (e.g. https://analytics.myapp.com) to avoid adblockers blocking PostHog requests.
// PostHog offers a managed reverse proxy for this — see:
// https://posthog.com/docs/advanced/proxy/managed-reverse-proxy
const posthogHost = process.env.NEXT_PUBLIC_POSTHOG_HOST || 'https://us.i.posthog.com';

if (posthogKey) {
  try {
    posthog.init(posthogKey, {
      api_host: posthogHost,
      ui_host: 'https://us.posthog.com',
      defaults: POSTHOG_DEFAULTS_DATE,
    });
  } catch (e) {
    console.warn('[PostHog] Failed to initialize:', e);
  }
}
