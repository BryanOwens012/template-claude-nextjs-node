#!/usr/bin/env bash
# Tests for scripts/check-hooks-installed.sh, on synthetic repos: the states worth testing are
# ones the real clone is never in (a hooks path that resolves to nothing, a hook with no
# dispatcher, no tracked hooks at all).
#
# Run: bash scripts/tests/check-hooks-installed.test.sh   (or via scripts/run-shell-tests.sh)
#
# `set -e` is deliberately absent so a failing assertion is recorded rather than aborting the
# run. bash 3.2 compatible: no arrays, no mapfile, no globstar.
set -u

unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_OBJECT_DIRECTORY \
	GIT_ALTERNATE_OBJECT_DIRECTORIES GIT_COMMON_DIR GIT_NAMESPACE \
	GIT_PREFIX GIT_QUARANTINE_PATH

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT="$REPO_ROOT/scripts/check-hooks-installed.sh"

SB=$(mktemp -d "${TMPDIR:-/tmp}/check-hooks.XXXXXX") || exit 1
cleanup() {
	# Guarded delete: only a directory this suite created, matched on its own marker name.
	case "${SB:-}" in
	*/check-hooks.??????) [ -d "$SB" ] && rm -rf -- "$SB" ;;
	esac
}
trap cleanup EXIT INT TERM
# macOS mktemp returns /var/..., while the script reports the physical /private/var/... path.
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
assert_eq() { # expected actual label
	if [ "$1" = "$2" ]; then ok "$3"; else ko "$3 (expected '$1', got '$2')"; fi
}
assert_contains() { # haystack needle label
	case "$1" in
	*"$2"*) ok "$3" ;;
	*) ko "$3 (output lacks '$2'): $1" ;;
	esac
}

# Builds a git repo at $1 with tracked hook bodies pre-commit and post-merge under .husky/.
# core.hooksPath is left for the case to set.
mk_repo() {
	mkdir -p "$1/.husky" || return 1
	git -C "$1" -c init.defaultBranch=main init -q || return 1
	printf '#!/usr/bin/env sh\nexit 0\n' >"$1/.husky/pre-commit"
	printf '#!/usr/bin/env sh\nexit 0\n' >"$1/.husky/post-merge"
}

# Populates a dispatcher directory at $1 with one executable per name in $2 (space-separated).
mk_dispatchers() {
	mkdir -p "$1" || return 1
	for n in $2; do
		printf '#!/usr/bin/env sh\nexit 0\n' >"$1/$n"
		chmod +x "$1/$n"
	done
}

run_in() { # dir -> sets OUT and RC
	OUT=$(cd "$1" && bash "$SCRIPT" 2>&1)
	RC=$?
}

echo "check-hooks-installed.test.sh"

# 1. The defect: hooksPath set to a directory that does not exist.
r="$SB/missing-dir"
mk_repo "$r"
git -C "$r" config core.hooksPath .husky/_
run_in "$r"
assert_eq 1 "$RC" "hooksPath resolving to nothing fails"
assert_contains "$OUT" "$r/.husky/_" "names the resolved directory"
assert_contains "$OUT" "does not exist" "says the directory does not exist"

# 2. Positive control: every tracked hook has an executable dispatcher.
r="$SB/good"
mk_repo "$r"
mk_dispatchers "$r/.husky/_" "pre-commit post-merge"
git -C "$r" config core.hooksPath .husky/_
run_in "$r"
assert_eq 0 "$RC" "positive control passes"
assert_contains "$OUT" "OK" "positive control prints OK"

# 3. One tracked hook without its dispatcher.
r="$SB/one-missing"
mk_repo "$r"
mk_dispatchers "$r/.husky/_" "pre-commit"
git -C "$r" config core.hooksPath .husky/_
run_in "$r"
assert_eq 1 "$RC" "missing dispatcher fails"
assert_contains "$OUT" "post-merge" "names the hook whose dispatcher is missing"

# 3b. A dispatcher that exists but is not executable counts as missing.
r="$SB/not-exec"
mk_repo "$r"
mk_dispatchers "$r/.husky/_" "pre-commit post-merge"
chmod -x "$r/.husky/_/post-merge"
git -C "$r" config core.hooksPath .husky/_
run_in "$r"
assert_eq 1 "$RC" "non-executable dispatcher fails"
assert_contains "$OUT" "post-merge" "names the non-executable dispatcher's hook"

# 4. core.hooksPath unset.
r="$SB/unset"
mk_repo "$r"
mk_dispatchers "$r/.husky/_" "pre-commit post-merge"
run_in "$r"
assert_eq 1 "$RC" "unset hooksPath fails"
assert_contains "$OUT" "core.hooksPath is unset" "says hooksPath is unset"

# 5. An absolute core.hooksPath is honored as-is.
r="$SB/absolute"
mk_repo "$r"
mk_dispatchers "$SB/abs-dispatchers" "pre-commit post-merge"
git -C "$r" config core.hooksPath "$SB/abs-dispatchers"
run_in "$r"
assert_eq 0 "$RC" "absolute hooksPath passes"
assert_contains "$OUT" "$SB/abs-dispatchers" "absolute path reported unchanged"

# 6. No tracked hooks at all must fail, not report nothing to verify.
r="$SB/no-hooks"
mkdir -p "$r/.husky"
git -C "$r" -c init.defaultBranch=main init -q
mk_dispatchers "$r/.husky/_" "pre-commit"
git -C "$r" config core.hooksPath .husky/_
run_in "$r"
assert_eq 1 "$RC" "no tracked hooks fails"
assert_contains "$OUT" "no tracked hooks" "says no tracked hooks were found"

# 7. Outside a git working tree it refuses.
mkdir -p "$SB/plain"
OUT=$(cd "$SB/plain" && GIT_CEILING_DIRECTORIES="$SB" bash "$SCRIPT" 2>&1)
RC=$?
assert_eq 1 "$RC" "outside a git tree refuses"
assert_contains "$OUT" "not inside a git working tree" "says it is not in a git tree"

# 8. Runs from a subdirectory: the hooks path resolves against the top of the working tree.
r="$SB/subdir"
mk_repo "$r"
mkdir -p "$r/apps/api"
mk_dispatchers "$r/.husky/_" "pre-commit post-merge"
git -C "$r" config core.hooksPath .husky/_
run_in "$r/apps/api"
assert_eq 0 "$RC" "relative hooksPath resolves against the toplevel from a subdirectory"

echo "check-hooks-installed.test.sh: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
