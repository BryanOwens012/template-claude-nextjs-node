'use client';

import { useQueryClient } from '@tanstack/react-query';
import { usePathname, useRouter } from 'next/navigation';
import { useEffect } from 'react';
import { useTRPC } from '@/lib/trpc';
import { runWhenIdle } from './idle';
import { type TopLevelRoute, topLevelRoutes } from './routes';

/**
 * Aggressive page prefetching: whenever the user lands on a top-level page,
 * prefetch all the other top-level pages — both the route (bundle/components)
 * and the data queries each page depends on. Deferred to browser idle time so
 * it never blocks the page the user is on.
 *
 * Mounted once via <PagePrefetcher /> in the root layout.
 */
export const usePrefetchPages = () => {
  const router = useRouter();
  const pathname = usePathname();
  const queryClient = useQueryClient();
  const trpc = useTRPC();

  useEffect(() => {
    // The data queries each top-level page renders with. Keep this in sync
    // when adding pages or changing what a page fetches.
    const getQueriesForRoute = (route: TopLevelRoute) => {
      switch (route) {
        case '/':
          return [trpc.health.check.queryOptions()];
        case '/about':
        case '/dashboard':
          return [];
      }
    };

    return runWhenIdle(() => {
      for (const route of topLevelRoutes) {
        if (route === pathname) {
          continue;
        }
        router.prefetch(route);
        for (const queryOptions of getQueriesForRoute(route)) {
          void queryClient.prefetchQuery(queryOptions);
        }
      }
    });
  }, [pathname, queryClient, router, trpc]);
};
