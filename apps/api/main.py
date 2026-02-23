"""
FastAPI Application Template with Redis and Supabase

This is a minimal FastAPI application with Redis and Supabase integration.
Includes health check endpoint and connectivity tests.
"""

import os
import socket
from contextlib import asynccontextmanager
from typing import Any, Dict, Optional

import redis.asyncio as redis
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from supabase import create_client, Client

# Global clients
redis_client: Optional[redis.Redis] = None
redis_available = True
supabase_client: Optional[Client] = None
supabase_available = True


@asynccontextmanager
async def lifespan(app: FastAPI):
    """
    Lifespan context manager for startup and shutdown events.
    Initializes Redis and Supabase connections on startup and closes them on shutdown.
    """
    global redis_client, redis_available, supabase_client, supabase_available

    # Startup: Initialize Redis
    redis_url = os.getenv("REDIS_URL", "redis://localhost:6379")
    print(f"🔌 Redis: Initializing connection to {redis_url.split('@')[-1]}")

    try:
        # Create Redis client with Railway-compatible settings
        redis_client = redis.from_url(
            redis_url,
            encoding="utf-8",
            decode_responses=True,
            # Railway IPv6 support - socket family 0 means dual-stack (try IPv6, fallback to IPv4)
            # https://docs.railway.com/reference/errors/enotfound-redis-railway-internal
            socket_family=0,  # 0 = AF_UNSPEC (dual-stack DNS resolution)
            socket_connect_timeout=10,  # 10 second connection timeout
            socket_keepalive=True,
            socket_keepalive_options={
                socket.TCP_KEEPIDLE: 30,  # Start keepalive after 30 seconds
                socket.TCP_KEEPINTVL: 10,  # Interval between keepalive probes
                socket.TCP_KEEPCNT: 3,  # Number of keepalive probes
            },
            retry_on_timeout=True,
            health_check_interval=30,  # Health check every 30 seconds
        )

        # Test connection
        await redis_client.ping()
        print("✅ Redis: Connected and ready")
        redis_available = True

    except Exception as e:
        print(f"❌ Redis: Connection failed: {str(e)}")
        print("⚠️  Redis: Continuing without cache (graceful degradation)")
        redis_client = None
        redis_available = False

    # Startup: Initialize Supabase
    supabase_url = os.getenv("SUPABASE_URL")
    supabase_key = os.getenv("SUPABASE_SERVICE_ROLE_KEY") or os.getenv("SUPABASE_KEY")

    if supabase_url and supabase_key:
        print(f"🔌 Supabase: Initializing connection to {supabase_url}")
        try:
            supabase_client = create_client(supabase_url, supabase_key)
            print("✅ Supabase: Client initialized and ready")
            supabase_available = True
        except Exception as e:
            print(f"❌ Supabase: Initialization failed: {str(e)}")
            print("⚠️  Supabase: Continuing without database (graceful degradation)")
            supabase_client = None
            supabase_available = False
    else:
        print("⚠️  Supabase: Missing credentials (SUPABASE_URL or SUPABASE_KEY)")
        print("⚠️  Supabase: Continuing without database")
        supabase_available = False

    yield

    # Shutdown: Close connections
    if redis_client:
        try:
            await redis_client.aclose()
            print("✅ Redis: Connection closed gracefully")
        except Exception as e:
            print(f"❌ Redis: Error during shutdown: {str(e)}")

    # Supabase client doesn't require explicit closing
    if supabase_client:
        print("✅ Supabase: Session ended")


# Initialize FastAPI app
app = FastAPI(
    title="FastAPI Template",
    description="Next.js + FastAPI template with Redis and Supabase",
    version="1.0.0",
    lifespan=lifespan,
)

# Configure CORS
# Update origins based on your frontend URL
origins = os.getenv("CORS_ORIGINS", "http://localhost:3000").split(",")

app.add_middleware(
    CORSMiddleware,
    allow_origins=origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# Pydantic models
class HealthResponse(BaseModel):
    status: str
    redis: str
    supabase: str
    message: str


class CacheTestResponse(BaseModel):
    action: str
    key: str
    value: Optional[str]
    cached: bool
    redis_available: bool


# Routes
@app.get("/")
async def root() -> Dict[str, str]:
    """Root endpoint - API information"""
    return {
        "name": "FastAPI Template",
        "version": "1.0.0",
        "docs": "/docs",
        "health": "/health",
    }


@app.get("/health", response_model=HealthResponse)
async def health_check() -> HealthResponse:
    """
    Health check endpoint for Railway and monitoring.
    Tests Redis and Supabase connectivity.
    """
    redis_status = "unavailable"
    supabase_status = "unavailable"

    # Check Redis
    if redis_client:
        try:
            await redis_client.ping()
            redis_status = "connected"
        except Exception as e:
            redis_status = f"error: {str(e)}"
            print(f"❌ Redis health check failed: {str(e)}")

    # Check Supabase
    if supabase_client and supabase_available:
        try:
            # Simple query to check connection
            supabase_client.table("_supabase_migrations").select("*").limit(1).execute()
            supabase_status = "connected"
        except Exception as e:
            # If migrations table doesn't exist, try a simpler check
            try:
                # Just check if we can access the client
                if supabase_client:
                    supabase_status = "initialized"
            except:
                supabase_status = f"error: {str(e)}"
                print(f"❌ Supabase health check failed: {str(e)}")

    services = []
    if redis_status == "connected":
        services.append("Redis")
    if supabase_status in ["connected", "initialized"]:
        services.append("Supabase")

    return HealthResponse(
        status="healthy" if services else "degraded",
        redis=redis_status,
        supabase=supabase_status,
        message=f"API is running with {', '.join(services)}" if services else "API is running (no services connected)",
    )


@app.get("/redis/test", response_model=CacheTestResponse)
async def test_redis_connection() -> CacheTestResponse:
    """
    Test Redis connectivity by setting and getting a value.
    Useful for debugging Redis connection issues.
    """
    if not redis_client or not redis_available:
        return CacheTestResponse(
            action="none",
            key="test:connection",
            value=None,
            cached=False,
            redis_available=False,
        )

    try:
        # Test SET operation
        test_key = "test:connection"
        test_value = "FastAPI + Redis working!"

        await redis_client.set(test_key, test_value, ex=60)  # Expires in 60 seconds
        print(f"✅ Redis SET: {test_key} = {test_value}")

        # Test GET operation
        retrieved_value = await redis_client.get(test_key)
        print(f"✅ Redis GET: {test_key} = {retrieved_value}")

        return CacheTestResponse(
            action="set_and_get",
            key=test_key,
            value=retrieved_value,
            cached=True,
            redis_available=True,
        )

    except Exception as e:
        print(f"❌ Redis test failed: {str(e)}")
        raise HTTPException(
            status_code=500, detail=f"Redis operation failed: {str(e)}"
        )


@app.post("/redis/cache/{key}")
async def set_cache(key: str, value: str, ttl: int = 300) -> Dict[str, Any]:
    """
    Set a value in Redis cache with optional TTL (time-to-live).

    Args:
        key: Cache key
        value: Value to cache
        ttl: Time-to-live in seconds (default: 300 = 5 minutes)
    """
    if not redis_client or not redis_available:
        raise HTTPException(
            status_code=503, detail="Redis is not available"
        )

    try:
        await redis_client.set(key, value, ex=ttl)
        return {
            "action": "set",
            "key": key,
            "value": value,
            "ttl": ttl,
            "success": True,
        }
    except Exception as e:
        raise HTTPException(
            status_code=500, detail=f"Failed to set cache: {str(e)}"
        )


@app.get("/redis/cache/{key}")
async def get_cache(key: str) -> Dict[str, Any]:
    """
    Get a value from Redis cache.

    Args:
        key: Cache key to retrieve
    """
    if not redis_client or not redis_available:
        raise HTTPException(
            status_code=503, detail="Redis is not available"
        )

    try:
        value = await redis_client.get(key)
        return {
            "action": "get",
            "key": key,
            "value": value,
            "found": value is not None,
        }
    except Exception as e:
        raise HTTPException(
            status_code=500, detail=f"Failed to get cache: {str(e)}"
        )


@app.delete("/redis/cache/{key}")
async def delete_cache(key: str) -> Dict[str, Any]:
    """
    Delete a value from Redis cache.

    Args:
        key: Cache key to delete
    """
    if not redis_client or not redis_available:
        raise HTTPException(
            status_code=503, detail="Redis is not available"
        )

    try:
        deleted_count = await redis_client.delete(key)
        return {
            "action": "delete",
            "key": key,
            "deleted": deleted_count > 0,
        }
    except Exception as e:
        raise HTTPException(
            status_code=500, detail=f"Failed to delete cache: {str(e)}"
        )


@app.get("/supabase/test")
async def test_supabase_connection() -> Dict[str, Any]:
    """
    Test Supabase connectivity.
    Useful for debugging Supabase connection issues.

    Returns basic connection info without requiring any tables to exist.
    """
    if not supabase_client or not supabase_available:
        return {
            "supabase_available": False,
            "message": "Supabase client not initialized",
            "details": "Check SUPABASE_URL and SUPABASE_KEY environment variables",
        }

    try:
        # Test that client is initialized
        return {
            "supabase_available": True,
            "message": "Supabase client initialized successfully",
            "url": os.getenv("SUPABASE_URL", "not set"),
            "note": "To test database operations, create a table and use Supabase client methods",
        }
    except Exception as e:
        print(f"❌ Supabase test failed: {str(e)}")
        raise HTTPException(
            status_code=500, detail=f"Supabase test failed: {str(e)}"
        )


# Example: Add your API routes here
# Example Supabase query:
# @app.get("/api/users")
# async def get_users():
#     if not supabase_client:
#         raise HTTPException(status_code=503, detail="Supabase not available")
#
#     try:
#         response = supabase_client.table("users").select("*").execute()
#         return {"users": response.data}
#     except Exception as e:
#         raise HTTPException(status_code=500, detail=str(e))


if __name__ == "__main__":
    import uvicorn

    # For local development
    uvicorn.run(app, host="0.0.0.0", port=8000, reload=True)
