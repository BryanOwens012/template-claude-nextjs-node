#!/usr/bin/env bash
# Tests for scripts/new-worktree.sh.
#
# Provisioning itself (four `npm ci` passes plus an api build) is deliberately NOT run under
# test; it would move the suite out of the cheap band for no extra coverage. What is tested:
# the argument and refusal gates that run before any worktree is created, and the
# exclude_tree function, lifted out of the script by anchor and ASSERTED to have been found
# (a moved anchor would otherwise yield an empty function and a green suite testing nothing).
#
# Run: bash scripts/tests/new-worktree.test.sh   (or via scripts/run-shell-tests.sh)
set -u

unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_OBJECT_DIRECTORY \
	GIT_ALTERNATE_OBJECT_DIRECTORIES GIT_COMMON_DIR GIT_NAMESPACE \
	GIT_PREFIX GIT_QUARANTINE_PATH

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT="$REPO_ROOT/scripts/new-worktree.sh"

SB=$(mktemp -d "${TMPDIR:-/tmp}/new-worktree.XXXXXX") || exit 1
cleanup() {
	case "${SB:-}" in
	*/new-worktree.??????) [ -d "$SB" ] && rm -rf -- "$SB" ;;
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

echo "new-worktree.test.sh"

# A fixture repo so ROOT resolves; the gates under test all fire before `git worktree add`.
fx="$SB/repo"
mkdir -p "$fx"
git -C "$fx" -c init.defaultBranch=main init -q
echo hi >"$fx/README.md"
git -C "$fx" add README.md
git -C "$fx" commit -q -m init

# 1. No arguments: usage, exit 2, nothing created.
OUT=$(cd "$fx" && bash "$SCRIPT" 2>&1)
RC=$?
assert_eq 2 "$RC" "no arguments exits 2"
assert_contains "$OUT" "usage:" "no arguments prints usage"

# 2. One argument is also usage.
OUT=$(cd "$fx" && bash "$SCRIPT" "$SB/wt" 2>&1)
RC=$?
assert_eq 2 "$RC" "one argument exits 2"

# 3. An existing target path is refused, untouched, and no worktree is registered.
mkdir -p "$SB/existing"
echo keep >"$SB/existing/marker"
OUT=$(cd "$fx" && bash "$SCRIPT" "$SB/existing" some-branch 2>&1)
RC=$?
assert_eq 1 "$RC" "existing target refuses"
assert_contains "$OUT" "already exists" "existing target names the refusal"
assert_eq keep "$(cat "$SB/existing/marker")" "existing target left untouched"
wt_count=$(git -C "$fx" worktree list | wc -l | tr -d ' ')
assert_eq 1 "$wt_count" "no worktree registered on refusal"

# 4. Outside a git repo it refuses before doing anything.
mkdir -p "$SB/plain"
OUT=$(cd "$SB/plain" && GIT_CEILING_DIRECTORIES="$SB" bash "$SCRIPT" "$SB/wt2" b 2>&1)
RC=$?
assert_eq 1 "$RC" "outside a repo refuses"
assert_contains "$OUT" "run this from inside the repo" "outside a repo says so"
if [ ! -e "$SB/wt2" ]; then ok "outside a repo creates nothing"; else ko "outside a repo created $SB/wt2"; fi

# 5. exclude_tree, extracted by anchor. The extraction must be non-empty or the rest of this
#    block tests nothing.
helper="$SB/exclude_tree.sh"
sed -n '/^exclude_tree() {$/,/^}$/p' "$SCRIPT" >"$helper"
if [ -s "$helper" ] && grep -q 'metadata_never_index' "$helper"; then
	ok "exclude_tree extracted from the script"
	# shellcheck disable=SC1090 # helper is generated above from the script under test
	. "$helper"

	d="$SB/tree"
	mkdir -p "$d"
	exclude_tree "$d"
	RC=$?
	assert_eq 0 "$RC" "exclude_tree returns 0 on a directory"
	if [ -f "$d/.metadata_never_index" ]; then ok "Spotlight marker written"; else ko "Spotlight marker missing in $d"; fi

	# Missing directory is a no-op, not an error.
	exclude_tree "$SB/does-not-exist" 2>"$SB/err"
	RC=$?
	assert_eq 0 "$RC" "exclude_tree on a missing directory returns 0"
	assert_eq "" "$(cat "$SB/err")" "exclude_tree on a missing directory prints nothing"
	if [ ! -e "$SB/does-not-exist" ]; then ok "missing directory not created"; else ko "missing directory was created"; fi

	# Time Machine arm: only meaningful where the control reads Included, since a temp
	# directory that is itself already excluded makes subject and control identical.
	if command -v tmutil >/dev/null 2>&1; then
		ctrl="$SB/control"
		mkdir -p "$ctrl"
		ctrl_state=$(tmutil isexcluded "$ctrl" 2>/dev/null)
		case "$ctrl_state" in
		*"[Included]"*)
			subj_state=$(tmutil isexcluded "$d" 2>/dev/null)
			assert_contains "$subj_state" "[Excluded]" "Time Machine exclusion applied"
			;;
		*)
			echo "  skip Time Machine arm: control '$ctrl' already reads '$ctrl_state', so the assertion cannot fail here"
			;;
		esac
	else
		echo "  skip Time Machine arm: tmutil not present on this platform"
	fi
else
	ko "exclude_tree could not be extracted from $SCRIPT (anchor moved?)"
fi

# 6. The workspace list names every directory that actually carries a lockfile, root first.
listed=$(sed -n 's/^WORKSPACE_DIRS=(\(.*\))$/\1/p' "$SCRIPT")
assert_eq "." "${listed%% *}" "workspace list starts with the root"
actual=$(cd "$REPO_ROOT" && git ls-files '*package-lock.json' 'package-lock.json' | sed 's#/package-lock.json$##; s#^package-lock.json$#.#' | LC_ALL=C sort | tr '\n' ' ')
expected=$(printf '%s\n' "$listed" | tr ' ' '\n' | LC_ALL=C sort | tr '\n' ' ')
assert_eq "$actual" "$expected" "workspace list matches the tracked lockfiles"

echo "new-worktree.test.sh: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
