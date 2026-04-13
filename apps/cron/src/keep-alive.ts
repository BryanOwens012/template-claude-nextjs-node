/**
 * Service Keep-Alive
 *
 * One-shot script that pings external services to prevent free-tier projects
 * from pausing due to inactivity.
 *
 * Not a cron itself — meant to be invoked on a schedule via a Railway
 * Function (e.g. every 6 days). The script runs once and exits.
 *
 * To add a new service: define a ping function (e.g. pingRedis), add it
 * to the `services` array, and set the required env vars.
 */

import { createClient } from '@supabase/supabase-js';

// --- Supabase ---

const pingSupabase = async () => {
  const url = process.env.SUPABASE_URL;
  const key = process.env.SUPABASE_SECRET_KEY;

  if (!url || !key) {
    throw new Error('Missing SUPABASE_URL or SUPABASE_SECRET_KEY');
  }

  const supabase = createClient(url, key, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  const { error } = await supabase.auth.admin.listUsers({ page: 1, perPage: 1 });

  if (error) {
    throw new Error(`Supabase query failed: ${error.message}`);
  }
};

// --- Run all keep-alive pings ---

const services: { name: string; ping: () => Promise<void> }[] = [
  { name: 'Supabase', ping: pingSupabase },
];

const run = async () => {
  console.log(`[${new Date().toISOString()}] Running keep-alive pings...`);

  const results = await Promise.allSettled(
    services.map(async (svc) => {
      await svc.ping();
      console.log(`  ${svc.name}: ok`);
    }),
  );

  const failures = results.filter((r) => r.status === 'rejected');

  for (let i = 0; i < results.length; i++) {
    const result = results[i];
    if (result.status === 'rejected') {
      console.error(`  ${services[i].name}: FAILED —`, result.reason);
    }
  }

  if (failures.length > 0) {
    process.exit(1);
  }

  console.log('All keep-alive pings succeeded.');
};

run();
