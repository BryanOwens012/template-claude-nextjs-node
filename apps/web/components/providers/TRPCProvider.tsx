'use client';

import type { AppRouter } from '@api/trpc/router';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { createTRPCClient, httpBatchLink } from '@trpc/client';
import { useState } from 'react';
import { TRPCProvider as BaseTRPCProvider } from '@/lib/trpc';

const makeQueryClient = () =>
  new QueryClient({
    defaultOptions: {
      queries: {
        staleTime: 30 * 1000,
        retry: 1,
      },
    },
  });

let browserQueryClient: QueryClient | undefined;

const getQueryClient = () => {
  if (typeof window === 'undefined') {
    return makeQueryClient();
  }
  if (!browserQueryClient) browserQueryClient = makeQueryClient();
  return browserQueryClient;
};

export const Providers = ({ children }: { children: React.ReactNode }) => {
  const queryClient = getQueryClient();
  const [trpcClient] = useState(() =>
    createTRPCClient<AppRouter>({
      links: [
        httpBatchLink({
          url: `${process.env.NEXT_PUBLIC_API_URL || 'http://localhost:8000'}/trpc`,
          // Custom header forces CORS preflight, blocking cross-site form attacks.
          // Value is arbitrary — used for debugging which client made the request.
          headers: () => ({ 'x-trpc-source': 'nextjs-client' }),
        }),
      ],
    }),
  );

  return (
    <QueryClientProvider client={queryClient}>
      <BaseTRPCProvider trpcClient={trpcClient} queryClient={queryClient}>
        {children}
      </BaseTRPCProvider>
    </QueryClientProvider>
  );
};
