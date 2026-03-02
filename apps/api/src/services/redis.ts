import Redis from 'ioredis';
import { getEnvironment } from '@/config/environment.js';

let redisClient: Redis | null = null;
let redisAvailable = false;

export const initRedis = async (): Promise<void> => {
  try {
    const env = getEnvironment();
    const redisUrl = new URL(env.REDIS_URL);

    redisClient = new Redis({
      host: redisUrl.hostname,
      port: redisUrl.port ? parseInt(redisUrl.port, 10) : 6379,
      password: redisUrl.password || undefined,
      family: 0, // Dual-stack IPv6/IPv4 — required for Railway
      connectTimeout: 10_000,
      keepAlive: 30_000,
      maxRetriesPerRequest: null, // Required for BullMQ compatibility
      enableReadyCheck: true,
      retryStrategy: (times) => Math.min(times * 50, 2_000),
      tls: redisUrl.protocol === 'rediss:' ? {} : undefined,
    });

    redisClient.on('error', (error) => {
      console.error('[redis] Connection error:', error);
    });

    const pong = await redisClient.ping();
    if (pong === 'PONG') {
      console.log('✅ Redis connected');
      redisAvailable = true;
    } else {
      console.warn('⚠️  Redis ping returned unexpected response');
      redisAvailable = false;
    }
  } catch (error) {
    console.warn(
      `⚠️  Redis initialization failed: ${error instanceof Error ? error.message : String(error)}`,
    );
    redisAvailable = false;
  }
};

export const getRedisClient = (): Redis | null => redisClient;
export const isRedisAvailable = (): boolean => redisAvailable;

export const closeRedis = async (): Promise<void> => {
  if (redisClient) {
    try {
      await redisClient.quit();
    } catch {
      await redisClient.disconnect();
    }
  }
};
