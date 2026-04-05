#!/usr/bin/env bash
# Tests API service connectivity via tRPC endpoints.
# Usage: bash scripts/test_services.sh [API_URL]
API_URL="${1:-http://localhost:8000}"
echo "=== Service Tests: $API_URL ==="

echo "--- /health (infra probe) ---"
curl -sf "$API_URL/health" | python3 -m json.tool 2>/dev/null || echo "❌ FAIL: /health"
echo ""

for ENDPOINT in "/trpc/health.check" "/trpc/redis.test" "/trpc/supabase.test"; do
	echo "--- $ENDPOINT ---"
	curl -sf -H "x-trpc-source: test-script" "$API_URL$ENDPOINT" | python3 -m json.tool 2>/dev/null || echo "❌ FAIL: $ENDPOINT"
	echo ""
done
echo "=== Done ==="
