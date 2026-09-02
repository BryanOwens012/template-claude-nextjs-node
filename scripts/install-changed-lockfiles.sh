#!/usr/bin/env sh
# Reinstall dependencies for every workspace whose package-lock.json changed between two revs.
#
# Shared by .husky/post-merge, post-rewrite, post-checkout, and post-commit so the four hooks
# cannot drift: a stale node_modules fails the next pre-commit build with "Cannot find
# module ..." for deps the incoming commits added, and that happens on a rebase, a branch
# switch, and a conflicted merge exactly as it does on a clean merge.
#
# Usage: install-changed-lockfiles.sh <old-rev> <new-rev> <hook-name>
#
# FAIL-OPEN BY DESIGN. This is convenience tooling wired into git hooks, so it must never
# abort or corrupt the git operation that invoked it: unresolvable revs exit 0 silently, and
# a failed install prints a loud "run it manually" warning to stderr and moves on. A hook
# that blocks a merge is worse than a stale node_modules, which the warning tells you how
# to fix.
#
# Git has no post-pull hook: `git pull` is fetch + merge (fires post-merge) or fetch +
# rebase (fires post-rewrite). Covering both is what makes "reinstall after a pull" true.
#
# For another package manager, swap the grep pattern and the install command
# (pnpm-lock.yaml -> pnpm install, bun.lock -> bun install, yarn.lock -> yarn install).

set -u

old="${1:-}"
new="${2:-}"
hook="${3:-lockfile-sync}"

[ -n "$old" ] && [ -n "$new" ] || exit 0

# Identical revs: a checkout that did not move HEAD, or a rebase that rewrote nothing, has no
# incoming dependency change by definition.
[ "$old" != "$new" ] || exit 0

# Resolve both revs BEFORE diffing. HEAD@{1} is absent on a fresh clone with no reflog, and
# ORIG_HEAD is absent until something sets it; either would make `git diff` fail noisily
# inside a hook for a case that is simply "nothing to do".
git rev-parse --verify --quiet "$old" >/dev/null 2>&1 || exit 0
git rev-parse --verify --quiet "$new" >/dev/null 2>&1 || exit 0

# git names changed files relative to the repo root, but a hook can run from a subdirectory.
# Anchor every path on the root, never the cwd.
root=$(git rev-parse --show-toplevel 2>/dev/null) || exit 0

# Checksum of a lockfile, or the literal `absent` when there is none, so creating or deleting
# a lockfile still reads as a change.
#
# Test existence first rather than leaning on `2>/dev/null`: redirections apply LEFT TO
# RIGHT, so a suppressor only covers redirections after it. `cksum <missing 2>/dev/null`
# still prints "No such file or directory", while `cksum 2>/dev/null <missing` is silent.
lockfile_checksum() {
	if [ -f "$1" ]; then
		# Suppressor BEFORE the redirection, per the rule above: `[ -f ]` proves the file
		# exists, not that it is readable, and an unreadable one fails the same way.
		cksum 2>/dev/null <"$1" || echo absent
	else
		echo absent
	fi
}

git diff --name-only "$old" "$new" 2>/dev/null |
	grep -E '(^|/)package-lock\.json$' |
	while IFS= read -r lock; do
		dir=$(dirname "$lock")
		[ -f "$root/$dir/package.json" ] || continue
		echo "$hook: $lock changed — running npm install in $dir"

		# Checksummed either side of the install because `npm install` reconciles manifest,
		# lockfile, and node_modules, and so REWRITES the lockfile whenever they have
		# drifted. That is a tooling edit to the file this repo treats as the source of
		# truth for exact versions, and it lands silently. The write is surfaced rather than
		# prevented: `npm ci` would prevent it but wipes node_modules first.
		before=$(lockfile_checksum "$root/$lock")

		# `</dev/null` is load-bearing. This loop's stdin IS the pipe carrying the remaining
		# lockfile paths, and every child inherits it, so an npm that reads stdin eats the
		# rest of the list: those packages are never installed and the loop still exits 0.
		# The test suite's npm stub drains stdin for exactly this reason.
		(cd "$root/$dir" && npm install --no-audit --no-fund </dev/null) ||
			echo "$hook: npm install FAILED in $dir — run it manually" >&2

		after=$(lockfile_checksum "$root/$lock")
		if [ "$before" != "$after" ]; then
			echo "$hook: NOTE — npm install rewrote $lock (manifest/lockfile drift). Review and commit it deliberately; do not let tooling own that file." >&2
		fi
	done

exit 0
