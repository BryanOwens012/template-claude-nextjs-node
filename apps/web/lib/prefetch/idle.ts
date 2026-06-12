/**
 * Run a callback when the browser is idle, so prefetching never delays or
 * competes with rendering the page the user is actually on.
 * Returns a cancel function (usable directly as a useEffect cleanup).
 */
export const runWhenIdle = (callback: () => void): (() => void) => {
  if (typeof window === 'undefined') {
    return () => {};
  }
  if (typeof window.requestIdleCallback === 'function') {
    const idleCallbackId = window.requestIdleCallback(callback);
    return () => window.cancelIdleCallback(idleCallbackId);
  }
  const timeoutId = window.setTimeout(callback, 1);
  return () => window.clearTimeout(timeoutId);
};
