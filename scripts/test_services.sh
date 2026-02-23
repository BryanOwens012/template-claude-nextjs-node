#!/usr/bin/env bash
# Tests API service connectivity.
# Usage: bash scripts/test_services.sh [API_URL]
API_URL="${1:-http://localhost:8000}"
echo "=== Service Tests: $API_URL ==="
for ENDPOINT in "/" "/health" "/redis/test" "/supabase/test"; do
  echo "--- $ENDPOINT ---"
  curl -sf "$API_URL$ENDPOINT" | python3 -m json.tool 2>/dev/null || echo "❌ FAIL: $ENDPOINT"
  echo ""
done
echo "=== Done ==="
