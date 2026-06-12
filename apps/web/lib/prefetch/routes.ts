/**
 * Top-level pages of the app. When the user lands on any of them, all the
 * others are prefetched (route bundle + data queries) in the background.
 * Add every new top-level page here, and register its data queries in
 * usePrefetchPages so the queries are warmed alongside the route.
 */
export const topLevelRoutes = ['/', '/about', '/dashboard'] as const;

export type TopLevelRoute = (typeof topLevelRoutes)[number];
