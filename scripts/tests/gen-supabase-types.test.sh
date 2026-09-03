#!/usr/bin/env bash
# Tests for scripts/gen-supabase-types.sh, in a sandboxed copy of the repo layout with `npx`
# stubbed on PATH. The stub's behavior is chosen per case through NPX_STUB_MODE, so every
# guard is watched to fire: a generator that fails, one that exits 0 with garbage, one that
# prints nothing, a missing env file, and an unparseable SUPABASE_URL must each leave the
# committed file byte-identical and the temp file gone.
#
# Run: bash scripts/tests/gen-supabase-types.test.sh   (or via scripts/run-shell-tests.sh)
set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT_SRC="$REPO_ROOT/scripts/gen-supabase-types.sh"

SB=$(mktemp -d "${TMPDIR:-/tmp}/gen-types.XXXXXX") || exit 1
cleanup() {
	case "${SB:-}" in
	*/gen-types.??????) [ -d "$SB" ] && rm -rf -- "$SB" ;;
	esac
}
trap cleanup EXIT INT TERM
SB=$(cd "$SB" && pwd -P)

pass=0
fail=0
ok() {
	pass=$((pass + 1))
	echo "  ok   $1"
}
ko() {
	fail=$((fail + 1))
	echo "  FAIL $1" >&2
}
assert_eq() {
	if [ "$1" = "$2" ]; then ok "$3"; else ko "$3 (expected '$1', got '$2')"; fi
}
assert_contains() {
	case "$1" in
	*"$2"*) ok "$3" ;;
	*) ko "$3 (output lacks '$2'): $1" ;;
	esac
}

# npx stub. NPX_ARGS_LOG records the argv; NPX_STUB_MODE picks the output:
#   ok       a valid types module that differs from the committed placeholder
#   fail     exit 1 with nothing on stdout (expired login, network, wrong id)
#   garbage  exit 0 with an HTML error page
#   empty    exit 0 with no output
STUB_BIN="$SB/bin"
mkdir -p "$STUB_BIN"
cat >"$STUB_BIN/npx" <<'STUB'
#!/usr/bin/env sh
printf '%s\n' "$*" >>"$NPX_ARGS_LOG"
case "${NPX_STUB_MODE:-ok}" in
ok)
	printf 'export type Json = string | number\n\nexport type Database = {\n  public: {\n    Tables: { widgets: { Row: { id: string } } }\n  }\n}\n'
	;;
fail) echo "Unauthorized. Run supabase login." >&2; exit 1 ;;
garbage) printf '<html><body>502 Bad Gateway</body></html>\n' ;;
empty) : ;;
esac
exit 0
STUB
chmod +x "$STUB_BIN/npx"
export PATH="$STUB_BIN:$PATH"
export NPX_ARGS_LOG="$SB/npx-args.log"
# The sandbox's own TMPDIR, so leaked temp files are countable.
export TMPDIR="$SB/tmp"
mkdir -p "$TMPDIR"

# Repo layout the script expects, with the script copied in so REPO_ROOT resolves to the sandbox.
R="$SB/repo"
mkdir -p "$R/scripts" "$R/apps/api" "$R/apps/shared/supabase"
cp "$SCRIPT_SRC" "$R/scripts/gen-supabase-types.sh"
SCRIPT="$R/scripts/gen-supabase-types.sh"
OUT="$R/apps/shared/supabase/types.ts"
PLACEHOLDER='// placeholder
export type Database = { public: { Tables: Record<string, never> } };
'
reset_fixture() {
	printf '%s' "$PLACEHOLDER" >"$OUT"
	chmod 644 "$OUT"
	printf 'PORT=8000\nSUPABASE_URL=https://abcdefghijkl.supabase.co\nSUPABASE_SECRET_KEY=sb_secret_x\n' >"$R/apps/api/.env"
	: >"$NPX_ARGS_LOG"
	rm -f "$TMPDIR"/supabase-types.*
}
run_script() { # [args...] -> OUT_TEXT, RC
	OUT_TEXT=$(bash "$SCRIPT" "$@" 2>&1)
	RC=$?
}
sum() { cksum <"$OUT" | cut -d' ' -f1,2; }
leaked_tmp() { find "$TMPDIR" -name 'supabase-types.*' | wc -l | tr -d ' '; }

echo "gen-supabase-types.test.sh"

# 1. Positive control: a good generator run replaces the file, mode 644, no temp left.
reset_fixture
before=$(sum)
run_script
assert_eq 0 "$RC" "ok: exit 0"
if [ "$(sum)" != "$before" ]; then ok "ok: file replaced"; else ko "ok: file unchanged after a good run"; fi
assert_contains "$(cat "$OUT")" "widgets" "ok: file holds the generator output"
assert_eq "644" "$(stat -f '%Lp' "$OUT" 2>/dev/null || stat -c '%a' "$OUT")" "ok: mode is 644 after the move"
assert_eq 0 "$(leaked_tmp)" "ok: no temp file left behind"
assert_contains "$(cat "$NPX_ARGS_LOG")" "supabase gen types typescript --project-id abcdefghijkl" "ok: project id extracted from SUPABASE_URL"
assert_contains "$OUT_TEXT" "project: abcdefghijkl" "ok: names the project it generated against"

# 2. Idempotent: a second identical run leaves the file byte-identical.
before=$(sum)
run_script
assert_eq 0 "$RC" "rerun: exit 0"
assert_eq "$before" "$(sum)" "rerun: file byte-identical"

# 3. Generator fails: committed file untouched, exit non-zero, temp removed. This is the
#    defect the script exists to prevent (a bare redirect would have truncated the file).
reset_fixture
before=$(sum)
NPX_STUB_MODE=fail run_script
if [ "$RC" -ne 0 ]; then ok "fail: exit non-zero ($RC)"; else ko "fail: exited 0"; fi
assert_eq "$before" "$(sum)" "fail: committed file byte-identical"
assert_contains "$(cat "$OUT")" "// placeholder" "fail: placeholder content intact"
assert_eq 0 "$(leaked_tmp)" "fail: temp file cleaned up"

# 4. Generator exits 0 with garbage: content guard refuses, file untouched.
reset_fixture
before=$(sum)
NPX_STUB_MODE=garbage run_script
assert_eq 1 "$RC" "garbage: exit 1"
assert_contains "$OUT_TEXT" "not a types module" "garbage: says why"
assert_eq "$before" "$(sum)" "garbage: committed file byte-identical"
assert_eq 0 "$(leaked_tmp)" "garbage: temp file cleaned up"

# 5. Generator exits 0 with no output: size guard refuses, file untouched.
reset_fixture
before=$(sum)
NPX_STUB_MODE=empty run_script
assert_eq 1 "$RC" "empty: exit 1"
assert_eq "$before" "$(sum)" "empty: committed file byte-identical"
assert_eq 0 "$(leaked_tmp)" "empty: temp file cleaned up"

# 6. Missing env file: refuses before calling the generator.
reset_fixture
rm -f "$R/apps/api/.env"
before=$(sum)
run_script
assert_eq 1 "$RC" "no env: exit 1"
assert_contains "$OUT_TEXT" ".env not found" "no env: names the missing file"
assert_eq 0 "$(grep -c . "$NPX_ARGS_LOG")" "no env: generator never invoked"
assert_eq "$before" "$(sum)" "no env: committed file byte-identical"

# 7. SUPABASE_URL missing or not a supabase.co URL: refuses rather than guessing.
reset_fixture
printf 'PORT=8000\n' >"$R/apps/api/.env"
run_script
assert_eq 1 "$RC" "no SUPABASE_URL: exit 1"
assert_contains "$OUT_TEXT" "refusing to guess" "no SUPABASE_URL: says it refuses to guess"
assert_eq 0 "$(grep -c . "$NPX_ARGS_LOG")" "no SUPABASE_URL: generator never invoked"
reset_fixture
printf 'SUPABASE_URL=http://localhost:54321\n' >"$R/apps/api/.env"
run_script
assert_eq 1 "$RC" "non-supabase.co URL: exit 1"
assert_eq 0 "$(grep -c . "$NPX_ARGS_LOG")" "non-supabase.co URL: generator never invoked"

# 8. Quoted URL in .env is accepted.
reset_fixture
printf 'SUPABASE_URL="https://zyxwvutsrqpo.supabase.co"\n' >"$R/apps/api/.env"
run_script
assert_eq 0 "$RC" "quoted URL: exit 0"
assert_contains "$(cat "$NPX_ARGS_LOG")" "--project-id zyxwvutsrqpo" "quoted URL: project id extracted"

# 9. --local skips the env file entirely and passes --local to the generator.
reset_fixture
rm -f "$R/apps/api/.env"
run_script --local
assert_eq 0 "$RC" "--local: exit 0 without an env file"
assert_contains "$(cat "$NPX_ARGS_LOG")" "gen types typescript --local" "--local: generator called with --local"
assert_contains "$(cat "$OUT")" "widgets" "--local: file replaced"

# 10. Unknown argument is a usage error and touches nothing.
reset_fixture
before=$(sum)
run_script --bogus
assert_eq 2 "$RC" "unknown arg: exit 2"
assert_eq "$before" "$(sum)" "unknown arg: file untouched"

echo "gen-supabase-types.test.sh: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
