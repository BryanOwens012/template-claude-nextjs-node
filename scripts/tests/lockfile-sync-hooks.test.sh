#!/usr/bin/env bash
# Tests for the lockfile-sync hooks (.husky/post-merge, post-rewrite, post-checkout,
# post-commit) against REAL git operations, with npm stubbed on PATH.
#
# Each case gets its own upstream + clone pair. The clone's core.hooksPath points at a shim
# directory OUTSIDE its working tree; each shim mirrors husky's dispatcher (`sh -e` on the
# repo's real .husky/<name> body) rather than relying on the gitignored .husky/_, which is
# absent on a fresh clone and would make every "expect 0 installs" case pass while testing
# nothing. The shared script the hooks call is a TRACKED file in the fixture's upstream, so
# no test scaffolding is ever untracked in the clone, and no fixture commit uses `git add -A`.
#
# Run: bash scripts/tests/lockfile-sync-hooks.test.sh   (or via scripts/run-shell-tests.sh)
set -u

unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_OBJECT_DIRECTORY \
	GIT_ALTERNATE_OBJECT_DIRECTORIES GIT_COMMON_DIR GIT_NAMESPACE \
	GIT_PREFIX GIT_QUARANTINE_PATH

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
HOOK_SRC="$REPO_ROOT/.husky"
SCRIPT_SRC="$REPO_ROOT/scripts/install-changed-lockfiles.sh"

SB=$(mktemp -d "${TMPDIR:-/tmp}/lockfile-hooks.XXXXXX") || exit 1
cleanup() {
	case "${SB:-}" in
	*/lockfile-hooks.??????) [ -d "$SB" ] && rm -rf -- "$SB" ;;
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

for h in post-merge post-rewrite post-checkout post-commit; do
	[ -f "$HOOK_SRC/$h" ] || {
		echo "lockfile-sync-hooks.test.sh: missing hook body $HOOK_SRC/$h" >&2
		exit 1
	}
done

# npm stub: drains stdin, logs its physical cwd.
STUB_BIN="$SB/bin"
mkdir -p "$STUB_BIN"
cat >"$STUB_BIN/npm" <<'STUB'
#!/usr/bin/env sh
cat >/dev/null
pwd -P >>"$NPM_LOG"
exit 0
STUB
chmod +x "$STUB_BIN/npm"
export PATH="$STUB_BIN:$PATH"
export NPM_LOG="$SB/npm.log"

# Shims mirroring husky's dispatcher: `sh -e` on the real hook body, args passed through.
SHIMS="$SB/hooks"
mkdir -p "$SHIMS"
for h in post-merge post-rewrite post-checkout post-commit; do
	printf '#!/usr/bin/env sh\nsh -e "%s/%s" "$@"\n' "$HOOK_SRC" "$h" >"$SHIMS/$h"
	chmod +x "$SHIMS/$h"
done

total_installs=0
installs() { grep -c . "$NPM_LOG"; }
reset_log() { : >"$NPM_LOG"; }
# Sets N to the install count and folds it into the run total. A function, not a command
# substitution: `$(...)` runs in a subshell, where the total would never reach this shell.
count() {
	N=$(installs)
	total_installs=$((total_installs + N))
}

# Fresh upstream + clone at $SB/<name>/{up,clone}. Sets UP, CL (physical paths). The clone
# gets the shims as its hooksPath; the upstream never runs a hook.
setup_pair() {
	pair="$SB/$1"
	UP="$pair/up"
	CL="$pair/clone"
	mkdir -p "$UP/apps/a" "$UP/scripts"
	git -C "$UP" -c init.defaultBranch=main init -q
	echo '{"name":"root"}' >"$UP/package.json"
	echo '{"v":0}' >"$UP/package-lock.json"
	echo '{"name":"a"}' >"$UP/apps/a/package.json"
	echo '{"v":0}' >"$UP/apps/a/package-lock.json"
	printf 'line1\nline2\nline3\n' >"$UP/file.txt"
	cp "$SCRIPT_SRC" "$UP/scripts/install-changed-lockfiles.sh"
	git -C "$UP" add -- package.json package-lock.json apps/a/package.json apps/a/package-lock.json file.txt scripts/install-changed-lockfiles.sh
	git -C "$UP" commit -q -m c0
	git clone -q "$UP" "$CL"
	git -C "$CL" config core.hooksPath "$SHIMS"
	# The test's own merge behavior must not depend on the machine's global pull.ff/pull.rebase.
	git -C "$CL" config pull.rebase false
	git -C "$CL" config pull.ff true
	CL=$(cd "$CL" && pwd -P)
	reset_log
}

up_bump() { # bump apps/a's lockfile upstream
	echo "{\"v\":$RANDOM$RANDOM}" >"$UP/apps/a/package-lock.json"
	git -C "$UP" add -- apps/a/package-lock.json
	git -C "$UP" commit -q -m "upstream bump"
}
up_edit_file() { # <content>: edit file.txt upstream (line 2)
	printf 'line1\n%s\nline3\n' "$1" >"$UP/file.txt"
	git -C "$UP" add -- file.txt
	git -C "$UP" commit -q -m "upstream edit"
}
cl_commit_note() { # <n>: a local commit in the clone touching a new file
	echo "$1" >"$CL/note$1.txt"
	git -C "$CL" add -- "note$1.txt"
	git -C "$CL" commit -q -m "local $1"
}

echo "lockfile-sync-hooks.test.sh"

# 1. First plain pull after a fresh clone. Deliberately first: HEAD@{1} must be unresolvable
#    before the pull (one-entry reflog) and resolvable after it, pointing at the pre-merge tip.
setup_pair first-pull
if git -C "$CL" rev-parse --verify --quiet 'HEAD@{1}' >/dev/null 2>&1; then
	ko "fresh clone: HEAD@{1} unexpectedly resolvable"
else
	ok "fresh clone: HEAD@{1} unresolvable before the pull"
fi
pre=$(git -C "$CL" rev-parse HEAD)
up_bump
git -C "$CL" pull -q
assert_eq "$pre" "$(git -C "$CL" rev-parse 'HEAD@{1}')" "after the pull HEAD@{1} is the pre-merge tip"
count
assert_eq 1 "$N" "plain pull: exactly one install"
assert_eq 1 "$(grep -c -x -- "$CL/apps/a" "$NPM_LOG")" "plain pull: installed in apps/a"
reset_log

# 2. `git pull --rebase` with a local commit installs exactly once (post-rewrite; post-checkout
#    is guarded by the rebase-in-progress check).
setup_pair rebase-one
cl_commit_note 1
up_bump
git -C "$CL" pull -q --rebase
count
assert_eq 1 "$N" "pull --rebase with one local commit: exactly one install"
reset_log

# 3. Fast-forward `pull --rebase` (no local commits) installs once.
setup_pair rebase-ff
up_bump
git -C "$CL" pull -q --rebase
count
assert_eq 1 "$N" "fast-forward pull --rebase: exactly one install"
reset_log

# 4. A rebase replaying TWO local commits still sees the upstream change (pins ORIG_HEAD;
#    swap in HEAD@{1} and only this case goes red).
setup_pair rebase-two
cl_commit_note 1
cl_commit_note 2
up_bump
git -C "$CL" pull -q --rebase
count
assert_eq 1 "$N" "pull --rebase replaying two commits: exactly one install"
reset_log

# 5. A branch switch that changes a lockfile installs.
setup_pair switch-lock
git -C "$CL" checkout -q -b feat
echo '{"v":"feat"}' >"$CL/apps/a/package-lock.json"
git -C "$CL" add -- apps/a/package-lock.json
git -C "$CL" commit -q -m "feat lock"
reset_log
git -C "$CL" checkout -q main
count
assert_eq 1 "$N" "branch switch across a lockfile change: one install"
reset_log
git -C "$CL" checkout -q feat
count
assert_eq 1 "$N" "branch switch back: one install"
reset_log

# 6. `git checkout -- <path>` does not install.
setup_pair file-checkout
echo dirty >"$CL/apps/a/package-lock.json"
git -C "$CL" checkout -q -- apps/a/package-lock.json
count
assert_eq 0 "$N" "file checkout: no install"
reset_log

# 7. A branch switch with identical lockfiles does not install.
setup_pair switch-same
git -C "$CL" checkout -q -b feat
cl_commit_note 1
reset_log
git -C "$CL" checkout -q main
count
assert_eq 0 "$N" "branch switch with no lockfile change: no install"
reset_log

# 8. `commit --amend` does not install, even when the amended commit touches a lockfile.
setup_pair amend
echo '{"v":"local"}' >"$CL/apps/a/package-lock.json"
git -C "$CL" add -- apps/a/package-lock.json
git -C "$CL" commit -q -m "local lock"
reset_log
git -C "$CL" commit -q --amend -m "local lock (amended)"
count
assert_eq 0 "$N" "commit --amend: no install"
reset_log

# 9. A CONFLICTED merge carrying a lockfile change installs exactly once (post-commit).
setup_pair conflict-lock
printf 'line1\nlocal\nline3\n' >"$CL/file.txt"
git -C "$CL" add -- file.txt
git -C "$CL" commit -q -m "local edit"
up_edit_file upstream
up_bump
reset_log
git -C "$CL" pull -q >/dev/null 2>&1
if git -C "$CL" rev-parse --verify --quiet MERGE_HEAD >/dev/null 2>&1; then
	ok "conflicted merge: MERGE_HEAD exists (the conflict was real)"
else
	ko "conflicted merge: expected a conflict, got none"
fi
assert_eq 0 "$(installs)" "conflicted merge: nothing installed while the merge is stopped"
printf 'line1\nresolved\nline3\n' >"$CL/file.txt"
git -C "$CL" add -- file.txt
git -C "$CL" commit -q -m "merge resolved" >/dev/null
count
assert_eq 1 "$N" "conflicted merge resolved: exactly one install"
assert_eq 1 "$(grep -c -x -- "$CL/apps/a" "$NPM_LOG")" "conflicted merge resolved: installed in apps/a"
reset_log

# 10. The same conflicted shape with NO lockfile change does not install.
setup_pair conflict-nolock
printf 'line1\nlocal\nline3\n' >"$CL/file.txt"
git -C "$CL" add -- file.txt
git -C "$CL" commit -q -m "local edit"
up_edit_file upstream
reset_log
git -C "$CL" pull -q >/dev/null 2>&1
printf 'line1\nresolved\nline3\n' >"$CL/file.txt"
git -C "$CL" add -- file.txt
git -C "$CL" commit -q -m "merge resolved" >/dev/null
count
assert_eq 0 "$N" "conflicted merge without a lockfile change: no install"
reset_log

# 11. An ordinary one-parent commit that edits a lockfile does not install. The only case
#     exercising post-commit's second-parent gate: remove the gate and only this goes red.
setup_pair plain-commit
echo '{"v":"hand-edited"}' >"$CL/apps/a/package-lock.json"
git -C "$CL" add -- apps/a/package-lock.json
reset_log
git -C "$CL" commit -q -m "hand-edit lockfile"
count
assert_eq 0 "$N" "ordinary commit editing a lockfile: no install"
reset_log

# Vacuity guard: a fixture whose hooks never fire makes every "0 installs" case pass while
# proving nothing. Something above must have installed.
if [ "$total_installs" -gt 0 ]; then
	ok "vacuity guard: $total_installs install(s) observed across the run"
else
	ko "vacuity guard: no case installed anything — the hooks never fired"
fi

echo "lockfile-sync-hooks.test.sh: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
