/**
 * Railway Infrastructure as Code — the single source of truth for this
 * project's Railway environment (replaces the deprecated root `railway.json`).
 *
 * Preview and apply with the Railway CLI (>= 5.42.1) from the repo root:
 *   railway config plan    # read-only diff against the linked environment
 *   railway config apply   # applies after confirmation
 *
 * Omit means delete: any service, database, or variable that exists in Railway
 * but is not declared here is REMOVED on apply. Declare every resource, and use
 * preserve() for secrets so their values stay in Railway and out of git.
 *
 * Docs: https://docs.railway.com/infrastructure-as-code
 *       https://docs.railway.com/infrastructure-as-code/reference
 */

import { readFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { defineRailway, fn, github, image, preserve, project, redis, service } from 'railway/iac';

// The GitHub repository Railway builds from. Change this when using the template
// for a new project.
const REPO = 'BryanOwens012/template-claude-nextjs-node';

const REPO_ROOT = resolve(dirname(fileURLToPath(import.meta.url)), '..');

// Railway Functions run a single inline script: the function image's `run.sh`
// takes the script source, base64-encoded, as its only argument. Reading it
// from the repo keeps `apps/cron/src/keep-alive.ts` the source of truth and
// makes an edit to that file show up as a diff in `railway config plan`.
const encodeFunctionScript = (relativePath: string): string => {
  const source = readFileSync(resolve(REPO_ROOT, relativePath));
  return `./run.sh ${source.toString('base64')}`;
};

export default defineRailway(() => {
  const cache = redis('Redis');

  const api = service('API', {
    // The Dockerfile copies `apps/shared/` alongside `apps/api/`, so the build
    // context must stay at the repo root.
    source: github(REPO, { branch: 'main', rootDirectory: '/' }),
    build: {
      builder: 'DOCKERFILE',
      dockerfilePath: 'apps/api/Dockerfile',
    },
    start: 'node --expose-gc dist/api/src/index.js',
    deploy: {
      restartPolicyType: 'ON_FAILURE',
      restartPolicyMaxRetries: 10,
    },
    // Private-network hostname (`api.railway.internal`). Generated public
    // domains are not managed here; custom ones go in `domains: [...]`.
    networking: { privateNetworkEndpoint: 'api' },
    env: {
      REDIS_URL: cache.env.REDIS_URL,
      SUPABASE_URL: preserve(),
      SUPABASE_SECRET_KEY: preserve(),
      CORS_ORIGINS: preserve(),
      // Every LLM call routes through OpenRouter (CLAUDE.md -> "Routing"). Declared so an
      // `apply` keeps the dashboard value; an undeclared variable is deleted on apply.
      OPENROUTER_API_KEY: preserve(),
      // Server-side analytics and LLM analytics (CLAUDE.md -> "LLM Observability").
      POSTHOG_API_KEY: preserve(),
      POSTHOG_HOST: preserve(),
    },
  });

  // Scheduled keep-alive ping (see apps/cron/src/keep-alive.ts). A one-shot
  // Railway Function: runs on the cron schedule, exits, and is never restarted.
  const keepAlive = fn('Keep-Alive', {
    source: image('ghcr.io/railwayapp/function-bun:1.3.0'),
    start: encodeFunctionScript('apps/cron/src/keep-alive.ts'),
    deploy: {
      cronSchedule: '0 0 * * *',
      restartPolicyType: 'NEVER',
    },
    networking: { privateNetworkEndpoint: 'keep-alive' },
    env: {
      SUPABASE_URL: preserve(),
      SUPABASE_SECRET_KEY: preserve(),
    },
  });

  return project('template-claude-nextjs-node', {
    resources: [cache, api, keepAlive],
  });
});
