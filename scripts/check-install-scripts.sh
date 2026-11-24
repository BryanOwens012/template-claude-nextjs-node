#!/usr/bin/env bash
#
# check-install-scripts.sh — fail when a dependency's install script has no recorded decision,
# or when a workspace stops refusing such scripts at install time.
#
# Run:  npm run check:install-scripts
#   (or: bash scripts/check-install-scripts.sh)
#
# npm (MIN_NPM and later) reads a decision per dependency install script from `allowScripts` in the
# workspace's package.json. By default it still RUNS a script with no decision and only
# prints a warning, so a new dependency's postinstall executes on the first install. Each
# workspace's .npmrc therefore sets strict-allow-scripts=true, which makes the install fail
# instead. This check holds both halves in the gauntlet:
#   - every workspace's effective strict-allow-scripts is true, so the .npmrc line cannot be
#     dropped silently;
#   - `npm install-scripts ls` lists nothing without a decision, naming any package that does.
#
# Three properties of `npm install-scripts ls` shape it, and each is a way it could otherwise
# pass having checked nothing:
#   - it exits 0 whether or not anything is unreviewed, so the --json output is what is read;
#   - it reports nothing unreviewed for a workspace with no installed tree, so a workspace
#     without node_modules/.package-lock.json is refused rather than passed;
#   - it does not understand npm workspaces, so it runs in each directory holding a tracked
#     package-lock.json, and finding none is a failure.
# An npm older than MIN_NPM has neither the command nor allowScripts, so it is refused too.
#
# Read-only: it lists and reads config, and never approves, denies, or installs.

set -u

PREFIX="check-install-scripts"
MIN_NPM="11.20.0"

ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || {
	printf '%s: FAIL — not inside a git working tree.\n' "$PREFIX" >&2
	exit 1
}
cd -- "$ROOT" || exit 1

# `npm run` exports the root's resolved config into the environment as npm_config_*, and npm
# reads those ahead of a workspace's own .npmrc, so every child npm below would report the
# root's settings instead of its own workspace's. Clear them so each workspace answers for
# itself. compgen -e lists exported names only, so no value is ever word-split.
for var in $(compgen -e); do
	case "$var" in
	npm_config_* | NPM_CONFIG_*) unset "$var" ;;
	esac
done

command -v python3 >/dev/null 2>&1 || {
	printf '%s: FAIL — python3 is not on PATH; it parses npm output here.\n' "$PREFIX" >&2
	exit 1
}

npm_version=$(npm --version 2>/dev/null) || {
	printf '%s: FAIL — npm is not on PATH.\n' "$PREFIX" >&2
	exit 1
}
version_ok=$(python3 -c '
import sys
def parse(s):
    return tuple(int(p) for p in s.split("-")[0].split(".")[:3])
try:
    print("yes" if parse(sys.argv[1]) >= parse(sys.argv[2]) else "no")
except ValueError:
    print("unparseable")
' "$npm_version" "$MIN_NPM")
case "$version_ok" in
yes) ;;
no)
	printf '%s: FAIL — npm %s has no allowScripts support; this check needs npm %s or later.\n' "$PREFIX" "$npm_version" "$MIN_NPM" >&2
	printf 'Run nvm install to get the Node in .nvmrc; engines.node in package.json is its floor.\n' >&2
	exit 1
	;;
*)
	printf '%s: FAIL — could not read npm version %s.\n' "$PREFIX" "$npm_version" >&2
	exit 1
	;;
esac

# Reads `npm install-scripts ls --json` on stdin and prints one unreviewed package name per
# line. Exit 2 means the output was not the shape this parser knows, which fails the check:
# an entry it cannot name must never read as "nothing unreviewed".
parse_ls='
import json, sys
try:
    data = json.load(sys.stdin)
    entries = data["allowScripts"]
    if not isinstance(entries, list):
        raise TypeError("allowScripts is not a list")
    for entry in entries:
        name = entry["name"]
        if not isinstance(name, str) or not name:
            raise ValueError("an entry has no package name")
        print(name)
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

	# Both halves: the committed file must carry the line, so a user-level or environment
	# setting cannot stand in for it on one machine, and npm must resolve it to true there,
	# so a later line in the file cannot switch it back off.
	if ! grep -qxE '[[:space:]]*strict-allow-scripts[[:space:]]*=[[:space:]]*true[[:space:]]*' -- "$dir/.npmrc" 2>/dev/null; then
		printf '%s: %s: %s/.npmrc does not set strict-allow-scripts=true, so npm would run an undecided install script there.\n' "$PREFIX" "$label" "$dir" >&2
		problems=$((problems + 1))
	else
		strict=$(cd -- "$dir" && npm config get strict-allow-scripts </dev/null 2>/dev/null)
		if [ "$strict" != "true" ]; then
			printf '%s: %s: %s/.npmrc sets strict-allow-scripts=true but npm resolves it to %s there; a later setting overrides it.\n' "$PREFIX" "$label" "$dir" "${strict:-unset}" >&2
			problems=$((problems + 1))
		fi
	fi

	if [ ! -f "$dir/node_modules/.package-lock.json" ]; then
		printf '%s: %s has no installed tree; run npm ci there first (an uninstalled workspace lists nothing and would read as clean).\n' "$PREFIX" "$label" >&2
		problems=$((problems + 1))
		continue
	fi

	if ! json=$(cd -- "$dir" && npm install-scripts ls --json </dev/null 2>/dev/null); then
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
			printf '    Review it, then from %s run: npm install-scripts approve %s (or deny %s).\n' "$label" "$name" "$name" >&2
		done <<<"$names"
		problems=$((problems + 1))
	fi
done < <(git ls-files -- 'package-lock.json' '*/package-lock.json')

if [ "$examined" -eq 0 ]; then
	printf '%s: FAIL — found no tracked package-lock.json; the walk examined nothing.\n' "$PREFIX" >&2
	exit 1
fi

if [ "$problems" -gt 0 ]; then
	printf '%s: FAIL — %d problem(s) across %d workspace(s).\n' "$PREFIX" "$problems" "$examined" >&2
	exit 1
fi

printf '%s: OK — %d workspace(s) refuse undecided install scripts, and every one has a decision in allowScripts.\n' "$PREFIX" "$examined"
