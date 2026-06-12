'use client';

import { useCallback, useEffect, useRef } from 'react';

const hoverIntentMs = 200;

/**
 * Hover-intent prefetching for table rows (and similar clickable items): when
 * the user hovers for more than 200ms, run the provided prefetch — typically
 * `router.prefetch(detailRoute)` plus `queryClient.prefetchQuery(...)` for the
 * queries the detail view needs. Fires at most once per mounted row.
 *
 * Usage:
 *   const hoverHandlers = useHoverPrefetch(() => {
 *     router.prefetch(`/items/${item.id}`);
 *     void queryClient.prefetchQuery(trpc.items.get.queryOptions({ id: item.id }));
 *   });
 *   <tr {...hoverHandlers} onClick={...}>
 */
export const useHoverPrefetch = (prefetch: () => void) => {
  const timeoutIdRef = useRef<number | null>(null);
  const didPrefetchRef = useRef(false);

  const cancelPendingPrefetch = useCallback(() => {
    if (timeoutIdRef.current !== null) {
      window.clearTimeout(timeoutIdRef.current);
      timeoutIdRef.current = null;
    }
  }, []);

  useEffect(() => cancelPendingPrefetch, [cancelPendingPrefetch]);

  const schedulePrefetch = useCallback(() => {
    if (didPrefetchRef.current || timeoutIdRef.current !== null) {
      return;
    }
    timeoutIdRef.current = window.setTimeout(() => {
      timeoutIdRef.current = null;
      didPrefetchRef.current = true;
      prefetch();
    }, hoverIntentMs);
  }, [prefetch]);

  return {
    onMouseEnter: schedulePrefetch,
    onMouseLeave: cancelPendingPrefetch,
    // Keyboard parity: focusing a row signals the same intent as hovering it
    onFocus: schedulePrefetch,
    onBlur: cancelPendingPrefetch,
  };
};
