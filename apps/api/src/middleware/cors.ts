import cors from 'cors';
import { getCorsOrigins } from '@/config/environment.js';

export const corsMiddleware = cors({
  origin: (origin, callback) => {
    const allowedOrigins = getCorsOrigins();

    if (!origin) return callback(null, true); // curl, Postman, server-to-server

    if (allowedOrigins === '*') return callback(null, true);

    const isLocalhost = origin.includes('localhost') || origin.includes('127.0.0.1');
    if (isLocalhost) return callback(null, true);

    if (Array.isArray(allowedOrigins) && allowedOrigins.includes(origin)) {
      return callback(null, true);
    }

    console.warn(`🚫 CORS rejected: ${origin}`);
    callback(new Error('CORS not allowed'));
  },
  credentials: true,
  methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization', 'x-trpc-source'],
  maxAge: 86400, // Cache preflight for 24h
});

export default corsMiddleware;
