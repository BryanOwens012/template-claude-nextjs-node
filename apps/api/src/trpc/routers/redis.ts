import { TRPCError } from '@trpc/server';
import { getRedisClient, isRedisAvailable } from '@/services/redis.js';
import { createRouter, publicProcedure } from '@/trpc/init.js';
import { CacheKeyInputSchema, CacheSetInputSchema } from '@/types/index.js';

export const redisRouter = createRouter({
  test: publicProcedure.query(async () => {
    if (!isRedisAvailable()) {
      return {
        action: 'none',
        key: 'test:connection',
        value: null,
        cached: false,
        redisAvailable: false,
      };
    }

    const redis = getRedisClient();
    if (!redis) {
      throw new TRPCError({ code: 'PRECONDITION_FAILED', message: 'Redis client not available' });
    }

    try {
      const key = 'test:connection';
      const value = 'Express + Redis working!';
      await redis.set(key, value, 'EX', 60);
      const retrieved = await redis.get(key);
      return { action: 'set_and_get', key, value: retrieved, cached: true, redisAvailable: true };
    } catch (error) {
      throw new TRPCError({
        code: 'INTERNAL_SERVER_ERROR',
        message: `Redis operation failed: ${error instanceof Error ? error.message : String(error)}`,
      });
    }
  }),

  cacheSet: publicProcedure.input(CacheSetInputSchema).mutation(async ({ input }) => {
    if (!isRedisAvailable()) {
      throw new TRPCError({ code: 'PRECONDITION_FAILED', message: 'Redis is not available' });
    }

    const redis = getRedisClient();
    if (!redis) {
      throw new TRPCError({ code: 'PRECONDITION_FAILED', message: 'Redis client not available' });
    }

    try {
      await redis.set(input.key, input.value, 'EX', input.ttl);
      return { action: 'set', key: input.key, value: input.value, ttl: input.ttl, success: true };
    } catch (error) {
      throw new TRPCError({
        code: 'INTERNAL_SERVER_ERROR',
        message: `Failed to set cache: ${error instanceof Error ? error.message : String(error)}`,
      });
    }
  }),

  cacheGet: publicProcedure.input(CacheKeyInputSchema).query(async ({ input }) => {
    if (!isRedisAvailable()) {
      throw new TRPCError({ code: 'PRECONDITION_FAILED', message: 'Redis is not available' });
    }

    const redis = getRedisClient();
    if (!redis) {
      throw new TRPCError({ code: 'PRECONDITION_FAILED', message: 'Redis client not available' });
    }

    try {
      const value = await redis.get(input.key);
      return { action: 'get', key: input.key, value, found: value !== null };
    } catch (error) {
      throw new TRPCError({
        code: 'INTERNAL_SERVER_ERROR',
        message: `Failed to get cache: ${error instanceof Error ? error.message : String(error)}`,
      });
    }
  }),

  cacheDelete: publicProcedure.input(CacheKeyInputSchema).mutation(async ({ input }) => {
    if (!isRedisAvailable()) {
      throw new TRPCError({ code: 'PRECONDITION_FAILED', message: 'Redis is not available' });
    }

    const redis = getRedisClient();
    if (!redis) {
      throw new TRPCError({ code: 'PRECONDITION_FAILED', message: 'Redis client not available' });
    }

    try {
      const count = await redis.del(input.key);
      return { action: 'delete', key: input.key, deleted: count > 0 };
    } catch (error) {
      throw new TRPCError({
        code: 'INTERNAL_SERVER_ERROR',
        message: `Failed to delete cache: ${error instanceof Error ? error.message : String(error)}`,
      });
    }
  }),
});
