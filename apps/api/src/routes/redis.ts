import { Router } from "express";
import createError from "http-errors";
import { getRedisClient, isRedisAvailable } from "@/services/redis.js";

const router = Router();

// GET /redis/test
router.get("/test", async (_req, res, next) => {
  if (!isRedisAvailable()) {
    res.json({ action: "none", key: "test:connection", value: null, cached: false, redisAvailable: false });
    return;
  }
  try {
    const redis = getRedisClient()!;
    const key = "test:connection";
    const value = "Express + Redis working!";
    await redis.set(key, value, "EX", 60);
    const retrieved = await redis.get(key);
    res.json({ action: "set_and_get", key, value: retrieved, cached: true, redisAvailable: true });
  } catch (error) {
    next(createError(500, `Redis operation failed: ${error instanceof Error ? error.message : String(error)}`));
  }
});

// POST /redis/cache/:key
router.post("/cache/:key", async (req, res, next) => {
  if (!isRedisAvailable()) return next(createError(503, "Redis is not available"));
  const { key } = req.params;
  const { value, ttl = "300" } = req.body as { value?: string; ttl?: string };
  if (!value) return next(createError(400, "Request body must include a 'value' field"));
  try {
    await getRedisClient()!.set(key, value, "EX", parseInt(ttl, 10));
    res.status(201).json({ action: "set", key, value, ttl: parseInt(ttl, 10), success: true });
  } catch (error) {
    next(createError(500, `Failed to set cache: ${error instanceof Error ? error.message : String(error)}`));
  }
});

// GET /redis/cache/:key
router.get("/cache/:key", async (req, res, next) => {
  if (!isRedisAvailable()) return next(createError(503, "Redis is not available"));
  try {
    const value = await getRedisClient()!.get(req.params.key);
    res.json({ action: "get", key: req.params.key, value, found: value !== null });
  } catch (error) {
    next(createError(500, `Failed to get cache: ${error instanceof Error ? error.message : String(error)}`));
  }
});

// DELETE /redis/cache/:key
router.delete("/cache/:key", async (req, res, next) => {
  if (!isRedisAvailable()) return next(createError(503, "Redis is not available"));
  try {
    const count = await getRedisClient()!.del(req.params.key);
    res.json({ action: "delete", key: req.params.key, deleted: count > 0 });
  } catch (error) {
    next(createError(500, `Failed to delete cache: ${error instanceof Error ? error.message : String(error)}`));
  }
});

export default router;
