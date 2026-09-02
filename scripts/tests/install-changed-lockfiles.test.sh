#!/usr/bin/env bash
# Tests for scripts/install-changed-lockfiles.sh, exercising the script's logic directly with
# npm stubbed on PATH.
#
# The stub DRAINS STDIN before logging: a stub that ignores stdin passes against a script that
# lets npm inherit the `while read` loop's pipe and one that redirects it alike, and the
# stdin-inheritance defect is the one that silently skips packages. It also logs the physical
# `pwd`, so assertions count WHICH directories were installed.
#
# Run: bash scripts/tests/install-changed-lockfiles.test.sh   (or via scripts/run-shell-tests.sh)
set -u

unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_OBJECT_DIRECTORY \
	GIT_ALTERNATE_OBJECT_DIRECTORIES GIT_COMMON_DIR GIT_NAMESPACE \
	GIT_PREFIX GIT_QUARANTINE_PATH

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT="$REPO_ROOT/scripts/install-changed-lockfiles.sh"

SB=$(mktemp -d "${TMPDIR:-/tmp}/lockfile-script.XXXXXX") || exit 1
cleanup() {
	case "${SB:-}" in
	*/lockfile-script.??????) [ -d "$SB" ] && rm -rf -- "$SB" ;;
	esac
}
trap cleanup EXIT INT TERM
# macOS mktemp returns /var/..., while `pwd` inside reports /private/var/...; compare physical.
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
assert_not_contains() {
	case "$1" in
	*"$2"*) ko "$3 (output unexpectedly contains '$2'): $1" ;;
	*) ok "$3" ;;
	esac
}

# npm stub. NPM_LOG receives one physical cwd per invocation; NPM_STUB_EXIT sets the exit
# code; NPM_STUB_REWRITE=1 makes it rewrite the lockfile the way a drifted manifest would.
STUB_BIN="$SB/bin"
mkdir -p "$STUB_BIN"
cat >"$STUB_BIN/npm" <<'STUB'
#!/usr/bin/env sh
cat >/dev/null
pwd -P >>"$NPM_LOG"
if [ "${NPM_STUB_REWRITE:-0}" = "1" ] && [ -f package-lock.json ]; then
	echo '{"rewritten":true}' >package-lock.json
fi
exit "${NPM_STUB_EXIT:-0}"
STUB
chmod +x "$STUB_BIN/npm"
export PATH="$STUB_BIN:$PATH"
export NPM_LOG="$SB/npm.log"
export NPM_STUB_EXIT=0
export NPM_STUB_REWRITE=0

# Fixture repo: root, apps/a, apps/b, apps/c each with package.json + package-lock.json, and
# apps/orphan with a lockfile but NO package.json.
R="$SB/repo"
mkdir -p "$R/apps/a" "$R/apps/b" "$R/apps/c" "$R/apps/orphan"
git -C "$R" -c init.defaultBranch=main init -q
for d in . apps/a apps/b apps/c; do
	echo '{"name":"x"}' >"$R/$d/package.json"
	echo '{"v":0}' >"$R/$d/package-lock.json"
done
echo '{"v":0}' >"$R/apps/orphan/package-lock.json"
echo base >"$R/file.txt"
git -C "$R" add -- package.json package-lock.json apps/a apps/b apps/c apps/orphan file.txt
git -C "$R" commit -q -m c0
C0=$(git -C "$R" rev-parse HEAD)

commit_bump() { # <dirs...>: bump each dir's lockfile and commit; prints the new sha
	for d in "$@"; do
		echo "{\"v\":$RANDOM$RANDOM}" >"$R/$d/package-lock.json"
		git -C "$R" add -- "$d/package-lock.json"
	done
	git -C "$R" commit -q -m "bump $*"
	git -C "$R" rev-parse HEAD
}

run_script() { # <cwd> <old> <new> [hook] -> sets OUT, ERR, RC; resets the log first
	: >"$NPM_LOG"
	OUT=$(cd "$1" && sh "$SCRIPT" "$2" "$3" "${4:-t}" 2>"$SB/err")
	RC=$?
	ERR=$(cat "$SB/err")
}
installs() { grep -c . "$NPM_LOG"; }
installed_in() { # <dir>, "." for the root
	if [ "$1" = "." ]; then grep -c -x -- "$R" "$NPM_LOG"; else grep -c -x -- "$R/$1" "$NPM_LOG"; fi
}

echo "install-changed-lockfiles.test.sh"

# 1. Positive control: one lockfile changed -> exactly one install, in that directory.
C1=$(commit_bump apps/a)
run_script "$R" "$C0" "$C1" post-merge
assert_eq 0 "$RC" "control: exit 0"
assert_eq 1 "$(installs)" "control: exactly one install"
assert_eq 1 "$(installed_in apps/a)" "control: installed in apps/a"
assert_contains "$OUT" "post-merge: apps/a/package-lock.json changed" "control: names the lockfile and hook"

# 2. Three lockfiles in one range -> one install each. Fails if npm inherits the loop's stdin.
C2=$(commit_bump apps/b apps/c .)
run_script "$R" "$C1" "$C2"
assert_eq 3 "$(installs)" "three changed lockfiles -> three installs"
assert_eq 1 "$(installed_in apps/b)" "installed in apps/b"
assert_eq 1 "$(installed_in apps/c)" "installed in apps/c"
assert_eq 1 "$(installed_in .)" "installed at the root"

# 3. A commit touching no lockfile -> no install.
echo changed >"$R/file.txt"
git -C "$R" add -- file.txt
git -C "$R" commit -q -m "no lockfile"
C3=$(git -C "$R" rev-parse HEAD)
run_script "$R" "$C2" "$C3"
assert_eq 0 "$RC" "no-lockfile commit: exit 0"
assert_eq 0 "$(installs)" "no-lockfile commit: no install"

# 4. Identical revs -> no install.
run_script "$R" "$C3" "$C3"
assert_eq 0 "$RC" "identical revs: exit 0"
assert_eq 0 "$(installs)" "identical revs: no install"

# 5. Unresolvable rev -> exit 0 silently.
run_script "$R" 'HEAD@{999}' HEAD
assert_eq 0 "$RC" "unresolvable rev: exit 0"
assert_eq 0 "$(installs)" "unresolvable rev: no install"
assert_eq "" "$ERR" "unresolvable rev: nothing on stderr"

# 6. Missing args -> exit 0.
: >"$NPM_LOG"
(cd "$R" && sh "$SCRIPT" >/dev/null 2>&1)
assert_eq 0 "$?" "no args: exit 0"
(cd "$R" && sh "$SCRIPT" "$C0" >/dev/null 2>&1)
assert_eq 0 "$?" "one arg: exit 0"
assert_eq 0 "$(installs)" "missing args: no install"

# 7. A lockfile with no sibling package.json is skipped.
C7=$(commit_bump apps/orphan)
run_script "$R" "$C3" "$C7"
assert_eq 0 "$(installs)" "orphan lockfile skipped"

# 8. A failing install warns on stderr and still exits 0.
C8=$(commit_bump apps/a)
NPM_STUB_EXIT=1 run_script "$R" "$C7" "$C8" post-rewrite
assert_eq 0 "$RC" "failed install: exit 0"
assert_contains "$ERR" "post-rewrite: npm install FAILED in apps/a" "failed install: warns naming the dir"
assert_eq 1 "$(installs)" "failed install: was attempted"

# 9. Invoked from a subdirectory, paths are anchored on the root, not the cwd.
C9=$(commit_bump apps/b apps/c)
run_script "$R/apps/a" "$C8" "$C9"
assert_eq 2 "$(installs)" "from a subdirectory: both installs happen"
assert_eq 1 "$(installed_in apps/b)" "from a subdirectory: apps/b installed"
assert_eq 1 "$(installed_in apps/c)" "from a subdirectory: apps/c installed"
assert_not_contains "$ERR" "No such file" "from a subdirectory: no cd failure"

# 10. A lockfile rewritten by the install is warned; a control where it is not must not warn.
C10=$(commit_bump apps/a)
NPM_STUB_REWRITE=1 run_script "$R" "$C9" "$C10" post-checkout
assert_contains "$ERR" "NOTE — npm install rewrote apps/a/package-lock.json" "rewrite: NOTE on stderr"
git -C "$R" checkout -q -- apps/a/package-lock.json
run_script "$R" "$C9" "$C10" post-checkout
assert_not_contains "$ERR" "rewrote" "no rewrite: no NOTE"

# 11. A range that DELETES a lockfile (package.json remains) is handled: exit 0, one install,
#     and no cksum noise about a missing file.
git -C "$R" rm -q -- apps/c/package-lock.json
git -C "$R" commit -q -m "drop apps/c lockfile"
C11=$(git -C "$R" rev-parse HEAD)
run_script "$R" "$C10" "$C11"
assert_eq 0 "$RC" "deleted lockfile: exit 0"
assert_eq 1 "$(installed_in apps/c)" "deleted lockfile: install runs (package.json still present)"
assert_not_contains "$ERR" "No such file" "deleted lockfile: no missing-file noise"

# 12. The redirection-order premise behind lockfile_checksum, executed rather than asserted.
noisy=$(sh -c 'cksum <"'"$SB"'/nope" 2>/dev/null' 2>&1)
quiet=$(sh -c 'cksum 2>/dev/null <"'"$SB"'/nope"' 2>&1)
assert_contains "$noisy" "No such file" "premise: suppressor after the redirection still prints"
assert_eq "" "$quiet" "premise: suppressor before the redirection is silent"

# 13. An existing-but-unreadable lockfile checksums as `absent` (skipped as root, who can read
#     anything). The helper is extracted to a FILE and sourced, not fed on stdin.
helper="$SB/lockfile_checksum.sh"
sed -n '/^lockfile_checksum() {$/,/^}$/p' "$SCRIPT" >"$helper"
if [ -s "$helper" ]; then
	ok "lockfile_checksum extracted"
	# shellcheck disable=SC1090 # helper is generated above from the script under test
	. "$helper"
	assert_eq absent "$(lockfile_checksum "$SB/nope")" "missing file -> absent"
	echo x >"$SB/readable"
	case "$(lockfile_checksum "$SB/readable")" in
	absent) ko "readable file -> absent (should be a checksum)" ;;
	*) ok "readable file -> checksum" ;;
	esac
	if [ "$(id -u)" = "0" ]; then
		echo "  skip unreadable-file case: running as root"
	else
		echo x >"$SB/unreadable"
		chmod 000 "$SB/unreadable"
		assert_eq absent "$(lockfile_checksum "$SB/unreadable" 2>&1)" "unreadable file -> absent, silently"
		chmod 600 "$SB/unreadable"
	fi
else
	ko "lockfile_checksum could not be extracted from $SCRIPT (anchor moved?)"
fi

echo "install-changed-lockfiles.test.sh: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
