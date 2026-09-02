#!/usr/bin/env bash
# Tests for scripts/run-shell-tests.sh, run against throwaway fixture repos so the runner's
# own failure modes can be exercised: a failing suite, a hanging suite, and a tree with no
# suites at all. A runner that reports green while running nothing is the defect it exists
# to close, so that case is the one that matters most here.
#
# Run: bash scripts/tests/run-shell-tests.test.sh   (or via scripts/run-shell-tests.sh)
set -u

unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_OBJECT_DIRECTORY \
	GIT_ALTERNATE_OBJECT_DIRECTORIES GIT_COMMON_DIR GIT_NAMESPACE \
	GIT_PREFIX GIT_QUARANTINE_PATH

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
RUNNER="$REPO_ROOT/scripts/run-shell-tests.sh"

SB=$(mktemp -d "${TMPDIR:-/tmp}/runner-test.XXXXXX") || exit 1
cleanup() {
	case "${SB:-}" in
	*/runner-test.??????) [ -d "$SB" ] && rm -rf -- "$SB" ;;
	esac
}
trap cleanup EXIT INT TERM

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
assert_not_contains() {
	case "$1" in
	*"$2"*) ko "$3 (output unexpectedly contains '$2'): $1" ;;
	*) ok "$3" ;;
	esac
}

# A fixture repo at $1; the runner resolves ROOT from its cwd, so each case runs from here.
mk_fixture() {
	mkdir -p "$1/scripts/tests"
	git -C "$1" -c init.defaultBranch=main init -q
}
# Writes a suite named $2 into fixture $1 with body $3.
mk_suite() {
	printf '#!/usr/bin/env bash\n%s\n' "$3" >"$1/scripts/tests/$2.test.sh"
}
run_runner() { # <fixture> [env assignments...] -> OUT, RC
	OUT=$(cd "$1" && shift && env "$@" bash "$RUNNER" 2>&1)
	RC=$?
}

echo "run-shell-tests.test.sh"

# 1. Positive control: two passing suites -> exit 0, both named, 2/2.
fx="$SB/pass"
mk_fixture "$fx"
mk_suite "$fx" a-first 'echo hello; exit 0'
mk_suite "$fx" b-second 'exit 0'
run_runner "$fx"
assert_eq 0 "$RC" "two passing suites: exit 0"
assert_contains "$OUT" "PASS scripts/tests/a-first.test.sh" "first suite reported PASS"
assert_contains "$OUT" "PASS scripts/tests/b-second.test.sh" "second suite reported PASS"
assert_contains "$OUT" "OK — 2/2 shell suites passed" "summary counts 2/2"

# 2. One failing suite among passing ones -> exit 1, the failure named, the others still run.
fx="$SB/fail"
mk_fixture "$fx"
mk_suite "$fx" a-pass 'exit 0'
mk_suite "$fx" b-fail 'echo boom >&2; exit 3'
mk_suite "$fx" c-pass 'exit 0'
run_runner "$fx"
assert_eq 1 "$RC" "a failing suite: exit 1"
assert_contains "$OUT" "FAIL scripts/tests/b-fail.test.sh" "failing suite reported FAIL"
assert_contains "$OUT" "PASS scripts/tests/c-pass.test.sh" "suites after the failure still run"
assert_contains "$OUT" "FAILED — 1 of 3 shell suites failed" "summary counts 1 of 3"
assert_contains "$OUT" "  - scripts/tests/b-fail.test.sh" "summary names the failing suite"

# 3. A hanging suite is killed on budget, with its whole process group, and reported as a
#    timeout rather than an ordinary failure. The suite spawns a grandchild so the group kill
#    is what is tested, not a kill of the direct child.
fx="$SB/hang"
mk_fixture "$fx"
mk_suite "$fx" a-hang "(sleep 600 & echo \$! >'$SB/grandchild.pid'; wait); exit 0"
start=$(date +%s)
run_runner "$fx" SUITE_BUDGET=2
elapsed=$(($(date +%s) - start))
assert_eq 1 "$RC" "hanging suite: exit 1"
assert_contains "$OUT" "exceeded its 2s budget" "hanging suite reported as a timeout"
assert_contains "$OUT" "(timed out after 2s)" "summary marks the timeout"
if [ "$elapsed" -lt 30 ]; then ok "runner returned in ${elapsed}s, within the bound"; else ko "runner took ${elapsed}s; the budget did not bound it"; fi
sleep 1
if [ -f "$SB/grandchild.pid" ] && kill -0 "$(cat "$SB/grandchild.pid")" 2>/dev/null; then
	ko "grandchild sleep survived the group kill"
	kill -KILL "$(cat "$SB/grandchild.pid")" 2>/dev/null
else
	ok "grandchild died with the process group"
fi

# 4. A suite that reads stdin must not eat the remaining suite list.
fx="$SB/stdin"
mk_fixture "$fx"
mk_suite "$fx" a-reads-stdin 'cat >/dev/null; exit 0'
mk_suite "$fx" b-after 'exit 0'
run_runner "$fx"
assert_eq 0 "$RC" "stdin-reading suite: exit 0"
assert_contains "$OUT" "PASS scripts/tests/b-after.test.sh" "suite after a stdin reader still runs"
assert_contains "$OUT" "2/2 shell suites passed" "both suites counted"

# 5. No suites at all must REFUSE, never report green.
fx="$SB/none"
mk_fixture "$fx"
run_runner "$fx"
assert_eq 1 "$RC" "no suites: exit 1"
assert_contains "$OUT" "REFUSING — found no *.test.sh suites" "no suites: says it refused"
assert_not_contains "$OUT" "OK —" "no suites: no OK line"

# 6. Suites under node_modules, dist, and .next are pruned from discovery.
fx="$SB/prune"
mk_fixture "$fx"
mk_suite "$fx" a-real 'exit 0'
mkdir -p "$fx/node_modules/dep" "$fx/apps/api/dist" "$fx/apps/web/.next"
printf '#!/usr/bin/env bash\nexit 9\n' >"$fx/node_modules/dep/x.test.sh"
printf '#!/usr/bin/env bash\nexit 9\n' >"$fx/apps/api/dist/y.test.sh"
printf '#!/usr/bin/env bash\nexit 9\n' >"$fx/apps/web/.next/z.test.sh"
run_runner "$fx"
assert_eq 0 "$RC" "pruned directories: exit 0"
assert_contains "$OUT" "1/1 shell suites passed" "only the real suite was discovered"

echo "run-shell-tests.test.sh: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
