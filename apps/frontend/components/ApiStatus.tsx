"use client";

import { useState, useEffect } from "react";
import api, { ApiError } from "@/lib/api";

interface HealthResponse {
  status: string;
  redis: string;
  supabase: string;
  message: string;
}

const ApiStatus = () => {
  const [health, setHealth] = useState<HealthResponse | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    const checkApiHealth = async () => {
      try {
        // Using the centralized API utility from lib/
        const data = await api.get<HealthResponse>("/health");
        setHealth(data);
        setError(null);
      } catch (err) {
        if (err instanceof ApiError) {
          setError(`API error: ${err.message} (Status: ${err.status})`);
        } else {
          setError(err instanceof Error ? err.message : "Failed to connect to API");
        }
        setHealth(null);
      } finally {
        setLoading(false);
      }
    };

    checkApiHealth();
  }, []);

  const getStatusColor = (status: string) => {
    if (status === "connected" || status === "healthy" || status === "initialized") {
      return "text-green-600 dark:text-green-400";
    }
    if (status === "unavailable") {
      return "text-yellow-600 dark:text-yellow-400";
    }
    return "text-red-600 dark:text-red-400";
  };

  const getStatusIcon = (status: string) => {
    if (status === "connected" || status === "healthy" || status === "initialized") {
      return "✓";
    }
    if (status === "unavailable") {
      return "⚠";
    }
    return "✗";
  };

  if (loading) {
    return (
      <div className="w-full max-w-md p-6 border border-gray-200 dark:border-gray-800 rounded-lg">
        <h3 className="text-lg font-semibold mb-3">API Status</h3>
        <p className="text-sm text-gray-600 dark:text-gray-400">Checking connection...</p>
      </div>
    );
  }

  if (error) {
    return (
      <div className="w-full max-w-md p-6 border border-red-200 dark:border-red-900 rounded-lg bg-red-50 dark:bg-red-950">
        <h3 className="text-lg font-semibold mb-3 text-red-900 dark:text-red-100">
          API Status
        </h3>
        <p className="text-sm text-red-700 dark:text-red-300">
          ✗ Unable to connect to API
        </p>
        <p className="text-xs text-red-600 dark:text-red-400 mt-2">
          {error}
        </p>
        <p className="text-xs text-gray-600 dark:text-gray-400 mt-3">
          Make sure the API is running at{" "}
          <code className="bg-red-100 dark:bg-red-900 px-1 rounded">
            {process.env.NEXT_PUBLIC_API_URL || "http://localhost:8000"}
          </code>
        </p>
      </div>
    );
  }

  return (
    <div className="w-full max-w-md p-6 border border-gray-200 dark:border-gray-800 rounded-lg">
      <h3 className="text-lg font-semibold mb-3">API Status</h3>

      {health && (
        <div className="space-y-2">
          <div className="flex items-center justify-between text-sm">
            <span className="text-gray-600 dark:text-gray-400">Overall:</span>
            <span className={`font-medium ${getStatusColor(health.status)}`}>
              {getStatusIcon(health.status)} {health.status}
            </span>
          </div>

          <div className="flex items-center justify-between text-sm">
            <span className="text-gray-600 dark:text-gray-400">Redis:</span>
            <span className={`font-medium ${getStatusColor(health.redis)}`}>
              {getStatusIcon(health.redis)} {health.redis}
            </span>
          </div>

          <div className="flex items-center justify-between text-sm">
            <span className="text-gray-600 dark:text-gray-400">Supabase:</span>
            <span className={`font-medium ${getStatusColor(health.supabase)}`}>
              {getStatusIcon(health.supabase)} {health.supabase}
            </span>
          </div>

          <p className="text-xs text-gray-500 dark:text-gray-500 mt-3 pt-3 border-t border-gray-200 dark:border-gray-800">
            {health.message}
          </p>
        </div>
      )}
    </div>
  );
};

export default ApiStatus;
