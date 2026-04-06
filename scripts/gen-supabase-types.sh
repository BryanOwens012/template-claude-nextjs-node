#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ENV_FILE="$REPO_ROOT/apps/api/.env"
OUT="$REPO_ROOT/apps/shared/supabase/types.ts"

if [[ ! -f $ENV_FILE ]]; then
	echo "Error: $ENV_FILE not found" >&2
	exit 1
fi

# Extract the project ID from SUPABASE_URL (e.g. https://abcdefgh.supabase.co → abcdefgh)
SUPABASE_URL=$(grep -E '^SUPABASE_URL=' "$ENV_FILE" | head -1 | cut -d'=' -f2 | tr -d ' ')
PROJECT_ID=$(echo "$SUPABASE_URL" | sed -E 's|^https?://([^.]+)\.supabase\.co.*|\1|')

if [[ -z $PROJECT_ID ]]; then
	echo "Error: Could not extract project ID from SUPABASE_URL in $ENV_FILE" >&2
	exit 1
fi

echo "Generating Supabase types for project: $PROJECT_ID"
echo "Output: $OUT"

cd "$REPO_ROOT/apps/api"
npx supabase gen types typescript --project-id "$PROJECT_ID" >"$OUT"

echo "Done."
