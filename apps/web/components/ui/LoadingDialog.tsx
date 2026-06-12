'use client';

import { useEffect, useState } from 'react';

const loadingDialogDelayMs = 200;

/**
 * Returns true only once `isLoading` has been true for longer than `delayMs`,
 * so operations that finish quickly never flash an indicator.
 */
export const useDelayedLoading = (
  isLoading: boolean,
  delayMs: number = loadingDialogDelayMs,
): boolean => {
  const [isVisible, setIsVisible] = useState(false);

  useEffect(() => {
    if (!isLoading) {
      setIsVisible(false);
      return;
    }
    const timeoutId = window.setTimeout(() => setIsVisible(true), delayMs);
    return () => window.clearTimeout(timeoutId);
  }, [isLoading, delayMs]);

  return isVisible;
};

/**
 * Small centered loading dialog for user-triggered loading (button clicks,
 * etc.). Appears only after the loading has lasted >200ms, and intentionally
 * has NO scrim/backdrop — a scrim flashing in and out on short loads is bad UI.
 */
const LoadingDialog = ({
  isLoading,
  label = 'Loading…',
  delayMs = loadingDialogDelayMs,
}: {
  isLoading: boolean;
  label?: string;
  delayMs?: number;
}) => {
  const isVisible = useDelayedLoading(isLoading, delayMs);

  if (!isVisible) {
    return null;
  }

  return (
    <div
      role="status"
      aria-live="polite"
      className="fixed left-1/2 top-1/2 z-50 -translate-x-1/2 -translate-y-1/2"
    >
      <div className="flex items-center gap-3 rounded-lg border border-gray-200 bg-white px-5 py-4 shadow-lg dark:border-gray-800 dark:bg-gray-900">
        <svg
          className="size-5 animate-spin text-blue-600 dark:text-blue-400"
          viewBox="0 0 24 24"
          fill="none"
          aria-hidden="true"
        >
          <circle
            className="opacity-25"
            cx="12"
            cy="12"
            r="10"
            stroke="currentColor"
            strokeWidth="4"
          />
          <path
            className="opacity-75"
            fill="currentColor"
            d="M4 12a8 8 0 018-8v4a4 4 0 00-4 4H4z"
          />
        </svg>
        <span className="text-sm font-medium text-gray-900 dark:text-gray-100">{label}</span>
      </div>
    </div>
  );
};

export default LoadingDialog;
