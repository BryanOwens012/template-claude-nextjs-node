'use client';

import { type FetchQueryOptions, useQueryClient } from '@tanstack/react-query';
import { useEffect } from 'react';
import { runWhenIdle } from './idle';

/**
 * Paginated-table prefetching: while the user is on one page of a paginated
 * table, warm the queries for the next and previous pages so paging either
 * direction is instant. Deferred to browser idle time.
 *
 * Usage:
 *   usePaginationPrefetch({
 *     page,
 *     lastPage: pageCount,
 *     getQueryOptionsForPage: (p) => trpc.items.list.queryOptions({ page: p }),
 *   });
 */
export const usePaginationPrefetch = ({
  page,
  firstPage = 1,
  lastPage,
  getQueryOptionsForPage,
}: {
  page: number;
  firstPage?: number;
  lastPage?: number;
  getQueryOptionsForPage: (page: number) => FetchQueryOptions;
}) => {
  const queryClient = useQueryClient();

  useEffect(() => {
    return runWhenIdle(() => {
      const adjacentPages = [page + 1, page - 1].filter(
        (adjacentPage) =>
          adjacentPage >= firstPage && (lastPage === undefined || adjacentPage <= lastPage),
      );
      for (const adjacentPage of adjacentPages) {
        void queryClient.prefetchQuery(getQueryOptionsForPage(adjacentPage));
      }
    });
  }, [page, firstPage, lastPage, getQueryOptionsForPage, queryClient]);
};
