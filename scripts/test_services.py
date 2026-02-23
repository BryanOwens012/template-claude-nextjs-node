#!/usr/bin/env python3
"""
Service Connectivity Test Script

This script demonstrates how to interact with the API service and test
connectivity to Redis and Supabase.

Usage:
    python scripts/test_services.py [--api-url http://localhost:8000]
"""

import argparse
import sys
import json
from typing import Dict, Any
try:
    import httpx
except ImportError:
    print("❌ Error: httpx is not installed")
    print("Install it with: pip install httpx")
    sys.exit(1)


# ANSI color codes for prettier output
class Colors:
    HEADER = '\033[95m'
    OKBLUE = '\033[94m'
    OKCYAN = '\033[96m'
    OKGREEN = '\033[92m'
    WARNING = '\033[93m'
    FAIL = '\033[91m'
    ENDC = '\033[0m'
    BOLD = '\033[1m'
    UNDERLINE = '\033[4m'


def print_header(text: str):
    """Print a formatted header"""
    print(f"\n{Colors.HEADER}{Colors.BOLD}{'=' * 60}{Colors.ENDC}")
    print(f"{Colors.HEADER}{Colors.BOLD}{text.center(60)}{Colors.ENDC}")
    print(f"{Colors.HEADER}{Colors.BOLD}{'=' * 60}{Colors.ENDC}\n")


def print_success(text: str):
    """Print a success message"""
    print(f"{Colors.OKGREEN}✓ {text}{Colors.ENDC}")


def print_error(text: str):
    """Print an error message"""
    print(f"{Colors.FAIL}✗ {text}{Colors.ENDC}")


def print_info(text: str):
    """Print an info message"""
    print(f"{Colors.OKCYAN}ℹ {text}{Colors.ENDC}")


def print_warning(text: str):
    """Print a warning message"""
    print(f"{Colors.WARNING}⚠ {text}{Colors.ENDC}")


def print_json(data: Dict[str, Any]):
    """Print formatted JSON"""
    print(f"{Colors.OKBLUE}{json.dumps(data, indent=2)}{Colors.ENDC}")


async def test_api_root(client: httpx.AsyncClient, base_url: str):
    """Test the API root endpoint"""
    print_header("Testing API Root Endpoint")

    try:
        response = await client.get(f"{base_url}/")

        if response.status_code == 200:
            print_success(f"API is responding (Status: {response.status_code})")
            print_info("Response:")
            print_json(response.json())
        else:
            print_error(f"Unexpected status code: {response.status_code}")
            print_info(f"Response: {response.text}")

        return response.status_code == 200
    except Exception as e:
        print_error(f"Failed to connect to API: {str(e)}")
        return False


async def test_health_endpoint(client: httpx.AsyncClient, base_url: str):
    """Test the health check endpoint"""
    print_header("Testing Health Check Endpoint")

    try:
        response = await client.get(f"{base_url}/health")

        if response.status_code == 200:
            data = response.json()
            print_success("Health check passed")
            print_info("Service Status:")
            print_json(data)

            # Check individual services
            if data.get("redis") == "connected":
                print_success("Redis: Connected")
            elif data.get("redis") == "unavailable":
                print_warning("Redis: Not configured (gracefully degraded)")
            else:
                print_warning(f"Redis: {data.get('redis', 'unknown')}")

            if data.get("supabase") in ["connected", "initialized"]:
                print_success(f"Supabase: {data.get('supabase').capitalize()}")
            elif data.get("supabase") == "unavailable":
                print_warning("Supabase: Not configured (gracefully degraded)")
            else:
                print_warning(f"Supabase: {data.get('supabase', 'unknown')}")

            return True
        else:
            print_error(f"Health check failed (Status: {response.status_code})")
            print_info(f"Response: {response.text}")
            return False

    except Exception as e:
        print_error(f"Failed to check health: {str(e)}")
        return False


async def test_redis_endpoint(client: httpx.AsyncClient, base_url: str):
    """Test the Redis test endpoint"""
    print_header("Testing Redis Connectivity")

    try:
        response = await client.get(f"{base_url}/redis/test")

        if response.status_code == 200:
            data = response.json()
            print_success("Redis test endpoint responded")
            print_info("Response:")
            print_json(data)

            if data.get("status") == "success":
                print_success("Redis operations working correctly")
                return True
            else:
                print_warning("Redis test returned non-success status")
                return False
        else:
            print_warning(f"Redis endpoint returned status {response.status_code}")
            print_info(f"Response: {response.text}")
            return False

    except Exception as e:
        print_error(f"Failed to test Redis: {str(e)}")
        return False


async def test_supabase_endpoint(client: httpx.AsyncClient, base_url: str):
    """Test the Supabase test endpoint"""
    print_header("Testing Supabase Connectivity")

    try:
        response = await client.get(f"{base_url}/supabase/test")

        if response.status_code == 200:
            data = response.json()
            print_success("Supabase test endpoint responded")
            print_info("Response:")
            print_json(data)

            if data.get("status") == "success":
                print_success("Supabase connection working correctly")
                return True
            else:
                print_warning("Supabase test returned non-success status")
                return False
        else:
            print_warning(f"Supabase endpoint returned status {response.status_code}")
            print_info(f"Response: {response.text}")
            return False

    except Exception as e:
        print_error(f"Failed to test Supabase: {str(e)}")
        return False


async def run_all_tests(base_url: str):
    """Run all service tests"""
    print(f"\n{Colors.BOLD}Starting Service Tests{Colors.ENDC}")
    print(f"{Colors.BOLD}API URL: {base_url}{Colors.ENDC}")

    results = {
        "api_root": False,
        "health": False,
        "redis": False,
        "supabase": False,
    }

    async with httpx.AsyncClient(timeout=10.0) as client:
        # Test API root
        results["api_root"] = await test_api_root(client, base_url)

        # Test health endpoint
        results["health"] = await test_health_endpoint(client, base_url)

        # Test Redis
        results["redis"] = await test_redis_endpoint(client, base_url)

        # Test Supabase
        results["supabase"] = await test_supabase_endpoint(client, base_url)

    # Print summary
    print_header("Test Summary")

    total = len(results)
    passed = sum(1 for v in results.values() if v)

    print(f"{Colors.BOLD}Results: {passed}/{total} tests passed{Colors.ENDC}\n")

    for test_name, passed in results.items():
        status = f"{Colors.OKGREEN}✓ PASS{Colors.ENDC}" if passed else f"{Colors.FAIL}✗ FAIL{Colors.ENDC}"
        print(f"  {test_name.replace('_', ' ').title()}: {status}")

    print()

    if passed == total:
        print_success("All tests passed! 🎉")
        return 0
    elif passed > 0:
        print_warning(f"{total - passed} test(s) failed")
        print_info("Note: Redis and Supabase failures are expected if not configured")
        return 0
    else:
        print_error("All tests failed - is the API running?")
        return 1


def main():
    """Main entry point"""
    parser = argparse.ArgumentParser(
        description="Test connectivity to API services"
    )
    parser.add_argument(
        "--api-url",
        default="http://localhost:8000",
        help="Base URL of the API (default: http://localhost:8000)"
    )

    args = parser.parse_args()

    # Run async tests
    import asyncio
    try:
        exit_code = asyncio.run(run_all_tests(args.api_url))
        sys.exit(exit_code)
    except KeyboardInterrupt:
        print_warning("\nTest interrupted by user")
        sys.exit(130)


if __name__ == "__main__":
    main()
