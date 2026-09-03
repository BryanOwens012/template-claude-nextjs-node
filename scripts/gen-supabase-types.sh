#!/usr/bin/env bash
#
# gen-supabase-types.sh — regenerate apps/shared/supabase/types.ts without ever leaving it damaged.
#
# Run:  bash scripts/gen-supabase-types.sh            # against the project named by SUPABASE_URL in apps/api/.env
#       bash scripts/gen-supabase-types.sh --local    # against a running local Supabase stack
#
# The only sanctioned way to regenerate the file. Never redirect the generator onto the
# committed file yourself: the shell truncates the target the instant it opens the redirect,
# before the generator emits a byte, so an expired login, a network failure, or a wrong
# project id leaves the repo's source of truth empty. This script generates to a temp file,
# checks the output is a types module, then moves it into place.
#
# The file is generated only. Nothing hand-written lives in it, so regeneration is a plain
# overwrite; biome.json exempts it from formatting and linting so the stored form is the
# generator's own output and a regeneration diff contains only schema changes.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ENV_FILE="$REPO_ROOT/apps/api/.env"
OUT="$REPO_ROOT/apps/shared/supabase/types.ts"

mode="project"
case "${1:-}" in
"") ;;
--local) mode="local" ;;
*)
	echo "usage: bash scripts/gen-supabase-types.sh [--local]" >&2
	exit 2
	;;
esac

if [[ $mode == "project" ]]; then
	if [[ ! -f $ENV_FILE ]]; then
		echo "Error: $ENV_FILE not found" >&2
		exit 1
	fi
	# `|| true` keeps the guard below reachable: under pipefail a grep that matches nothing
	# would otherwise kill the script before it can say what is missing.
	SUPABASE_URL=$(grep -E '^SUPABASE_URL=' "$ENV_FILE" | head -1 | cut -d'=' -f2- | tr -d ' "'"'" || true)
	PROJECT_ID=$(printf '%s' "$SUPABASE_URL" | sed -E 's|^https?://([^.]+)\.supabase\.co.*|\1|' || true)
	if [[ -z $SUPABASE_URL || -z $PROJECT_ID || $PROJECT_ID == "$SUPABASE_URL" ]]; then
		echo "Error: could not extract a project id from SUPABASE_URL in $ENV_FILE — refusing to guess the target" >&2
		exit 1
	fi
	echo "Generating Supabase types for project: $PROJECT_ID"
else
	echo "Generating Supabase types from the local Supabase stack"
fi
echo "Output: $OUT"

TMP="$(mktemp "${TMPDIR:-/tmp}/supabase-types.XXXXXX")"
cleanup() { rm -f "${TMP:?}"; }
trap cleanup EXIT

# Run from apps/api so npx resolves the locally pinned supabase CLI rather than fetching latest.
cd "$REPO_ROOT/apps/api"
if [[ $mode == "project" ]]; then
	npx supabase gen types typescript --project-id "$PROJECT_ID" >"$TMP"
else
	npx supabase gen types typescript --local >"$TMP"
fi

# Sniff the content, not just the size: a generator that exits 0 having printed an error
# page or an empty schema passes a bare -s check.
if [[ ! -s $TMP ]] || ! grep -q '^export type Database' "$TMP"; then
	echo "Error: generator output is empty or not a types module — $OUT left unchanged" >&2
	exit 1
fi

# mktemp creates 0600; the committed file is 0644. Fix the mode before the move so there is
# no window at the wrong mode.
chmod 644 "$TMP"
mv "$TMP" "$OUT"
trap - EXIT

echo "Done. Review the diff: it should contain only schema changes."
