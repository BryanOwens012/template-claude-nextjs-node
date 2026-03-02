import express from 'express';
import { getEnvironment } from '@/config/environment.js';
import { corsMiddleware } from '@/middleware/cors.js';
import { errorHandler } from '@/middleware/errorHandler.js';
import healthRouter from '@/routes/health.js';
import indexRouter from '@/routes/index.js';
import langfuseRouter from '@/routes/langfuse.js';
import redisRouter from '@/routes/redis.js';
import supabaseRouter from '@/routes/supabase.js';
import { closeLangfuse, initLangfuse } from '@/services/langfuse.js';
import { closeRedis, initRedis } from '@/services/redis.js';
import { initSupabase } from '@/services/supabase.js';
import { initTelemetry, shutdownTelemetry } from '@/services/telemetry.js';

const app = express();
const env = getEnvironment(); // Validates env vars; exits on failure

// Trust Railway's reverse proxy (required for accurate IP in headers)
app.set('trust proxy', 1);

// Middleware
app.use(express.json());
app.use(express.urlencoded({ extended: true }));
app.use(corsMiddleware);

// Routes — each router uses router.get("/") internally; path prefix set here
app.use('/', indexRouter);
app.use('/health', healthRouter);
app.use('/redis', redisRouter);
app.use('/supabase', supabaseRouter);
app.use('/langfuse', langfuseRouter);

// 404 handler (after all routes)
app.use((req, res) => {
  res.status(404).json({ error: 'Not Found', status: 404, path: req.path, method: req.method });
});

// Error handler (must be last)
app.use(errorHandler);

let server: ReturnType<typeof app.listen>;

const startServer = async (): Promise<void> => {
  try {
    initTelemetry();
    await initRedis();
    await initSupabase();
    await initLangfuse();

    const port = env.PORT; // already a number (z.coerce.number())
    server = app.listen(port, '0.0.0.0', () => {
      console.log(`API listening on port ${port}`);
      console.log(`Environment: ${env.NODE_ENV}`);
    });

    const shutdown = async (signal: string) => {
      console.log(`\n📍 Received ${signal}, shutting down gracefully...`);
      server.close(async () => {
        await shutdownTelemetry();
        await closeLangfuse();
        await closeRedis();
        process.exit(0);
      });
      setTimeout(() => process.exit(1), 30_000); // Force-kill after 30s
    };

    process.on('SIGTERM', () => shutdown('SIGTERM'));
    process.on('SIGINT', () => shutdown('SIGINT'));

    process.on('uncaughtException', (error) => {
      console.error('❌ Uncaught Exception:', error);
      process.exit(1);
    });
    process.on('unhandledRejection', (reason) => {
      console.error('❌ Unhandled Rejection:', reason);
      process.exit(1);
    });
  } catch (error) {
    console.error(
      '❌ Failed to start server:',
      error instanceof Error ? error.message : String(error),
    );
    process.exit(1);
  }
};

// ESM guard — only start when this file is the entry point
const isMainModule = import.meta.url === `file://${process.argv[1]}`;
if (isMainModule) {
  startServer();
}

export default app;
