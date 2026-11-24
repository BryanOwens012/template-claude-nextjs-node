#!/usr/bin/env bash
#
# check-install-scripts.sh — fail when a dependency's install script has no recorded decision,
# or when a workspace stops requiring the npm that skips such scripts.
#
# Run:  npm run check:install-scripts
#   (or: bash scripts/check-install-scripts.sh)
#
# npm 12 reads a decision per dependency install script from `allowScripts` in the workspace's
# package.json and skips any script with none, printing a notice; older npm runs it. Each
# workspace therefore requires npm 12 (`engines.npm`) and makes that binding with
# engine-strict=true in its .npmrc, so an older npm refuses to install instead. This check holds
# all of it in the gauntlet:
#   - every package.json declares engines.npm at MIN_NPM's major or later;
#   - every workspace's .npmrc sets engine-strict=true and npm resolves it to true there, so the
#     line cannot be dropped or overridden silently;
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
MIN_NPM="12.0.0"

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
	printf '%s: FAIL — npm %s runs undecided install scripts; this repo needs npm %s or later.\n' "$PREFIX" "$npm_version" "$MIN_NPM" >&2
	printf 'Run npm install -g npm@12 (after nvm install for the Node in .nvmrc).\n' >&2
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

	# engines.npm must require npm 12 or later, since that is what engine-strict enforces.
	if ! python3 -c '
import json, re, sys
engines = json.load(open(sys.argv[1])).get("engines") or {}
spec = engines.get("npm")
m = re.match(r"\s*>=\s*v?(\d+)", spec) if isinstance(spec, str) else None
sys.exit(0 if m and int(m.group(1)) >= int(sys.argv[2]) else 1)
' "$dir/package.json" "${MIN_NPM%%.*}" 2>/dev/null; then
		printf '%s: %s: %s/package.json does not declare engines.npm ">=%s" or later.\n' "$PREFIX" "$label" "$dir" "$MIN_NPM" >&2
		problems=$((problems + 1))
	fi

	# Both halves: the committed file must carry the line, so a user-level or environment
	# setting cannot stand in for it on one machine, and npm must resolve it to true there,
	# so a later line in the file cannot switch it back off.
	if ! grep -qxE '[[:space:]]*engine-strict[[:space:]]*=[[:space:]]*true[[:space:]]*' -- "$dir/.npmrc" 2>/dev/null; then
		printf '%s: %s: %s/.npmrc does not set engine-strict=true, so an npm older than %s would install there and run undecided install scripts.\n' "$PREFIX" "$label" "$dir" "$MIN_NPM" >&2
		problems=$((problems + 1))
	else
		strict=$(cd -- "$dir" && npm config get engine-strict </dev/null 2>/dev/null)
		if [ "$strict" != "true" ]; then
			printf '%s: %s: %s/.npmrc sets engine-strict=true but npm resolves it to %s there; a later setting overrides it.\n' "$PREFIX" "$label" "$dir" "${strict:-unset}" >&2
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

printf '%s: OK — %d workspace(s) require npm %s with engine-strict, and every install script has a decision in allowScripts.\n' "$PREFIX" "$examined" "${MIN_NPM%%.*}"
