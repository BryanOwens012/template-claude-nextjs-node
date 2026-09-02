#!/usr/bin/env bash
# run-shell-tests.sh — discover and run every bash test suite in the repo (any *.test.sh).
#
# Run:  npm run test:scripts:sh   (or: bash scripts/run-shell-tests.sh)
#
# Discovery is by `find`, never an enumerated list, so a NEW *.test.sh anywhere in the repo
# is picked up automatically: a suite cannot be added and silently never run. `find` rather
# than a `**` globstar because globstar is bash 4+; the default bash on macOS is 3.2.
#
# Every suite runs under a wall-clock budget that bounds its whole PROCESS GROUP, so a suite
# that hangs fails loudly and on schedule instead of stalling the gauntlet. `timeout` and
# `gtimeout` are absent on stock macOS, and a bound on the direct child alone lets a
# grandchild survive and re-parent to launchd, so the bound is a group kill.
#
# `set -e` is deliberately NOT set: a failing suite must not abort the run, since the point
# is to report every suite's result in one pass. Failures are collected and re-raised as
# this script's own exit code.
set -uo pipefail

# Git exports its repo pointers into every hook it runs (GIT_DIR, GIT_INDEX_FILE, and
# friends). The suites drive real git inside sandboxes they create, so an inherited pointer
# silently retargets every `git init`/`add`/`commit`/`checkout` at the AMBIENT repo. Scrub
# them before anything runs; unsetting an unset name is a no-op.
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_OBJECT_DIRECTORY \
	GIT_ALTERNATE_OBJECT_DIRECTORIES GIT_COMMON_DIR GIT_NAMESPACE \
	GIT_PREFIX GIT_QUARANTINE_PATH

ROOT="$(git rev-parse --show-toplevel)"
cd "$ROOT" || exit 1

# Per-suite wall-clock budget, in seconds. Generous for a normal suite and deliberately finite.
SUITE_BUDGET="${SUITE_BUDGET:-300}"

# Run one suite under a bound that covers its whole process group. `set -m` puts the child
# in its own group so `kill -- -$pid` reaches the suite AND everything it spawned without
# reaching this script. TERM first so a suite can clean up its temp dirs, KILL after a grace
# period so a wedged one still dies. Returns the suite's status, or 124 on timeout.
run_suite_bounded() {
	budget="$1"
	suite_path="$2"

	set -m
	bash "$suite_path" </dev/null &
	suite_pid=$!
	set +m

	# The reaper gets its own process group and its own stdio: it must not hold a caller's
	# pipe open for the full budget after the suite has already finished, and killing only
	# the subshell would strand the `sleep` inside it.
	set -m
	(
		sleep "$budget"
		kill -TERM -- -"$suite_pid" 2>/dev/null
		sleep 5
		kill -KILL -- -"$suite_pid" 2>/dev/null
	) >/dev/null 2>&1 &
	reaper_pid=$!
	set +m

	wait "$suite_pid"
	suite_rc=$?

	kill -TERM -- -"$reaper_pid" 2>/dev/null
	wait "$reaper_pid" 2>/dev/null

	# 143 = 128+SIGTERM, 137 = 128+SIGKILL: the reaper fired.
	if [ "$suite_rc" -eq 143 ] || [ "$suite_rc" -eq 137 ]; then
		return 124
	fi
	return "$suite_rc"
}

suites_run=0
suites_failed=0
failed_names=""

echo "run-shell-tests: discovering *.test.sh across the repo"
echo

while IFS= read -r suite; do
	[ -n "$suite" ] || continue
	rel="${suite#"$ROOT"/}"
	suites_run=$((suites_run + 1))
	echo "──────────────────────────────────────────────────────────────"
	echo "RUN  $rel  (budget ${SUITE_BUDGET}s)"
	echo "──────────────────────────────────────────────────────────────"
	# The suite's stdin is redirected from /dev/null inside run_suite_bounded. That is
	# load-bearing: this loop's stdin IS the heredoc holding the remaining suite paths, so a
	# suite that reads stdin would eat the rest of the list and the run would still exit 0.
	run_suite_bounded "$SUITE_BUDGET" "$suite"
	rc=$?
	if [ "$rc" -eq 0 ]; then
		echo "PASS $rel"
	elif [ "$rc" -eq 124 ]; then
		echo "FAIL $rel — exceeded its ${SUITE_BUDGET}s budget and was killed with its process group" >&2
		suites_failed=$((suites_failed + 1))
		failed_names="${failed_names}
  - ${rel} (timed out after ${SUITE_BUDGET}s)"
	else
		echo "FAIL $rel" >&2
		suites_failed=$((suites_failed + 1))
		failed_names="${failed_names}
  - ${rel}"
	fi
	echo
done <<EOF
$(find "$ROOT" \( -name node_modules -o -name .git -o -name dist -o -name .next \) -prune -o \
	-type f -name '*.test.sh' -print | LC_ALL=C sort)
EOF

# A runner that discovers nothing and exits 0 is the same class of bug this script exists
# to close: green while testing exactly nothing. Fail loudly instead.
if [ "$suites_run" -eq 0 ]; then
	echo "run-shell-tests: REFUSING — found no *.test.sh suites in $ROOT." >&2
	echo "  If the shell suites were genuinely all removed, remove this runner and its npm script too." >&2
	exit 1
fi

echo "=============================================================="
if [ "$suites_failed" -eq 0 ]; then
	echo "run-shell-tests: OK — $suites_run/$suites_run shell suites passed."
	exit 0
fi

echo "run-shell-tests: FAILED — $suites_failed of $suites_run shell suites failed:${failed_names}" >&2
exit 1
