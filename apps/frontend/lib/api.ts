/**
 * API Utility
 *
 * Centralized API client for making type-safe requests to the FastAPI backend.
 * This is an example of a general utility that belongs in lib/.
 */

const API_BASE_URL = process.env.NEXT_PUBLIC_API_URL || "http://localhost:8000";

/**
 * Custom error class for API errors
 */
export class ApiError extends Error {
  constructor(
    message: string,
    public status: number,
    public data?: unknown
  ) {
    super(message);
    this.name = "ApiError";
  }
}

/**
 * Generic API request handler
 */
const apiRequest = async <T>(
  endpoint: string,
  options: RequestInit = {}
): Promise<T> => {
  const url = `${API_BASE_URL}${endpoint}`;

  const defaultHeaders: HeadersInit = {
    "Content-Type": "application/json",
  };

  const config: RequestInit = {
    ...options,
    headers: {
      ...defaultHeaders,
      ...options.headers,
    },
  };

  try {
    const response = await fetch(url, config);

    if (!response.ok) {
      const errorData = await response.json().catch(() => ({}));
      throw new ApiError(
        errorData.detail || `API error: ${response.status}`,
        response.status,
        errorData
      );
    }

    // Handle 204 No Content
    if (response.status === 204) {
      return {} as T;
    }

    return await response.json();
  } catch (error) {
    if (error instanceof ApiError) {
      throw error;
    }

    // Network or parsing errors
    throw new ApiError(
      error instanceof Error ? error.message : "Unknown error occurred",
      0
    );
  }
};

/**
 * GET request
 */
export const get = <T>(endpoint: string, options?: RequestInit): Promise<T> => {
  return apiRequest<T>(endpoint, {
    ...options,
    method: "GET",
  });
};

/**
 * POST request
 */
export const post = <T, D = unknown>(
  endpoint: string,
  data?: D,
  options?: RequestInit
): Promise<T> => {
  return apiRequest<T>(endpoint, {
    ...options,
    method: "POST",
    body: data ? JSON.stringify(data) : undefined,
  });
};

/**
 * PUT request
 */
export const put = <T, D = unknown>(
  endpoint: string,
  data?: D,
  options?: RequestInit
): Promise<T> => {
  return apiRequest<T>(endpoint, {
    ...options,
    method: "PUT",
    body: data ? JSON.stringify(data) : undefined,
  });
};

/**
 * PATCH request
 */
export const patch = <T, D = unknown>(
  endpoint: string,
  data?: D,
  options?: RequestInit
): Promise<T> => {
  return apiRequest<T>(endpoint, {
    ...options,
    method: "PATCH",
    body: data ? JSON.stringify(data) : undefined,
  });
};

/**
 * DELETE request
 */
export const del = <T>(endpoint: string, options?: RequestInit): Promise<T> => {
  return apiRequest<T>(endpoint, {
    ...options,
    method: "DELETE",
  });
};

// Export as default object for convenience
const api = {
  get,
  post,
  put,
  patch,
  delete: del,
  ApiError,
};

export default api;
