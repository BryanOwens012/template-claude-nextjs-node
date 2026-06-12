'use client';

import { usePrefetchPages } from '@/lib/prefetch';

/**
 * Renders nothing; mounting it in the root layout makes every page landing
 * background-prefetch all the other top-level pages (routes + data queries).
 */
export const PagePrefetcher = () => {
  usePrefetchPages();
  return null;
};
