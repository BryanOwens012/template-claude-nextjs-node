#!/usr/bin/env bash
#
# check-install-scripts.sh — fail when a dependency's install script has no recorded decision.
#
# Run:  npm run check:install-scripts
#   (or: bash scripts/check-install-scripts.sh)
#
# npm 11.20+ skips every dependency install script that `allowScripts` in the workspace's
# package.json does not cover, and says so only in a notice at the end of the install. A new
# dependency that needs its postinstall then breaks at runtime while every other check stays
# green. This check turns that notice into a failure that names the package, so the decision
# (`npm install-scripts approve|deny <pkg>`) is made in the change that adds the dependency.
#
# Three properties of `npm install-scripts ls` shape it, and each is a way it could otherwise
# pass having checked nothing:
#   - it exits 0 whether or not anything is unreviewed, so the --json output is what is read;
#   - it reports nothing unreviewed for a workspace with no installed tree, so a workspace
#     without node_modules/.package-lock.json is refused rather than passed;
#   - it does not understand npm workspaces, so it runs in each directory holding a tracked
#     package-lock.json, and finding none is a failure.
# An npm older than 11.20 has no such command and ignores allowScripts, so it is refused too.
#
# Read-only: it lists, and never approves, denies, or installs.

set -u

PREFIX="check-install-scripts"
MIN_NPM="11.20.0"

ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || {
	printf '%s: FAIL — not inside a git working tree.\n' "$PREFIX" >&2
	exit 1
}
cd -- "$ROOT" || exit 1

npm_version=$(npm --version 2>/dev/null) || {
	printf '%s: FAIL — npm is not on PATH.\n' "$PREFIX" >&2
	exit 1
}
if ! python3 -c '
import sys
def parse(s):
    return tuple(int(p) for p in s.split("-")[0].split(".")[:3])
sys.exit(0 if parse(sys.argv[1]) >= parse(sys.argv[2]) else 1)
' "$npm_version" "$MIN_NPM" 2>/dev/null; then
	printf '%s: FAIL — npm %s does not enforce allowScripts; this check needs npm %s or later\n' "$PREFIX" "$npm_version" "$MIN_NPM" >&2
	printf '(bundled with Node 26.11 and later). Run nvm install to get the Node in .nvmrc.\n' >&2
	exit 1
fi

# Reads `npm install-scripts ls --json` on stdin and prints one unreviewed package name per
# line. Exit 2 means the output was not the shape this parser knows, which fails the check.
parse_ls='
import json, sys
try:
    data = json.load(sys.stdin)
    entries = data["allowScripts"]
    if not isinstance(entries, list):
        raise TypeError("allowScripts is not a list")
    for entry in entries:
        print(entry["name"])
except Exception as exc:
    print(f"unrecognized output: {exc}", file=sys.stderr)
    sys.exit(2)
'

problems=0
examined=0
while IFS= read -r lockfile; do
	dir=$(dirname -- "$lockfile")
	label=$dir
	[ "$label" = "." ] && label="(root)"
	examined=$((examined + 1))

	if [ ! -f "$dir/node_modules/.package-lock.json" ]; then
		printf '%s: %s has no installed tree; run npm ci there first (an uninstalled workspace lists nothing and would read as clean).\n' "$PREFIX" "$label" >&2
		problems=$((problems + 1))
		continue
	fi

	if ! json=$(cd -- "$dir" && npm install-scripts ls --json 2>/dev/null); then
		printf '%s: %s: npm install-scripts ls --json failed.\n' "$PREFIX" "$label" >&2
		problems=$((problems + 1))
		continue
	fi

	if ! names=$(printf '%s' "$json" | python3 -c "$parse_ls"); then
		printf '%s: %s: could not read the npm install-scripts ls --json output.\n' "$PREFIX" "$label" >&2
		problems=$((problems + 1))
		continue
	fi

	if [ -n "$names" ]; then
		while IFS= read -r name; do
			printf '%s: %s: %s has an install script with no decision in allowScripts.\n' "$PREFIX" "$label" "$name" >&2
		done <<<"$names"
		printf '    Review it, then from %s run: npm install-scripts approve %s (or deny %s).\n' "$label" "${names%%$'\n'*}" "${names%%$'\n'*}" >&2
		problems=$((problems + 1))
	fi
done < <(git ls-files -- 'package-lock.json' '*/package-lock.json')

if [ "$examined" -eq 0 ]; then
	printf '%s: FAIL — found no tracked package-lock.json; the walk examined nothing.\n' "$PREFIX" >&2
	exit 1
fi

if [ "$problems" -gt 0 ]; then
	printf '%s: FAIL — %d of %d workspace(s) have install scripts without a recorded decision.\n' "$PREFIX" "$problems" "$examined" >&2
	exit 1
fi

printf '%s: OK — every dependency install script in %d workspace(s) has a decision in allowScripts.\n' "$PREFIX" "$examined"
