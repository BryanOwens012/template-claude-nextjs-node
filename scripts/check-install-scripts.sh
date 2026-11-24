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
#   - every workspace's .npmrc sets the REQUIRED settings below (engine-strict, and installs from
#     the registry only), npm resolves each to that value there, and no committed .npmrc sets
#     allow-scripts or dangerously-allow-all-scripts, which would let scripts run regardless;
#   - every lockfile entry is fetched from the npm registry, or bundled inside one that is;
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
	npm_config_* | NPM_CONFIG_*) unset "$var" 2>/dev/null || true ;;
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

# Reads `npm config ls --json` on stdin and the committed .npmrc named by argv[1]. Prints one
# line per problem; exit 2 when the config output is unreadable, which fails the check.
check_config='
import json, re, sys
REQUIRED = {
    "engine-strict": True,
    "allow-git": "none",
    "allow-remote": "none",
    "allow-file": "none",
    "allow-directory": "none",
}
FORBIDDEN = ("allow-scripts", "dangerously-allow-all-scripts")
try:
    resolved = json.load(sys.stdin)
    if not isinstance(resolved, dict):
        raise TypeError("not an object")
except Exception as exc:
    print(f"npm config ls --json could not be read: {exc}")
    sys.exit(2)
path = sys.argv[1]
try:
    lines = open(path).read().splitlines()
except OSError:
    lines = []
committed = {}
for raw in lines:
    line = raw.strip()
    if not line or line[0] in "#;":
        continue
    key, _, value = line.partition("=")
    committed[key.strip()] = value.strip()
for key, want in REQUIRED.items():
    text = "true" if want is True else want
    if committed.get(key) != text:
        print(f"{path} does not set {key}={text}")
    elif resolved.get(key) != want:
        print(f"{path} sets {key}={text} but npm resolves it to {resolved.get(key)!r} there; a later setting overrides it")
for key in FORBIDDEN:
    if key in committed:
        print(f"{path} sets {key}, which lets install scripts run regardless of allowScripts")
if resolved.get("dangerously-allow-all-scripts") not in (False, None):
    print("npm resolves dangerously-allow-all-scripts to true there, so every install script would run")
'

# Reads the package-lock.json named by argv[1]. Exit 1, naming the entries, when one is fetched
# from anywhere but the npm registry; an entry bundled inside a registry tarball has no
# `resolved` of its own and is allowed. A workspace link or any other unresolved entry fails.
check_sources='
import json, sys
REGISTRY = "https://registry.npmjs.org/"
packages = json.load(open(sys.argv[1])).get("packages", {})
bad = []
for key, entry in packages.items():
    if not key:
        continue
    resolved = entry.get("resolved")
    if resolved is None:
        if not entry.get("inBundle"):
            bad.append(f"{key} (no registry source)")
    elif not resolved.startswith(REGISTRY):
        bad.append(f"{key} ({resolved})")
if bad:
    print(f"{sys.argv[1]} installs from outside the npm registry: " + "; ".join(bad[:5]) + (" ..." if len(bad) > 5 else ""))
    sys.exit(1)
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

	# Each REQUIRED setting must be committed in the workspace's .npmrc, so a user-level or
	# environment value cannot stand in for it on one machine, and npm must resolve it to that
	# value there, so a later line cannot switch it off. A committed allow-scripts or
	# dangerously-allow-all-scripts line fails outright, and the latter must resolve to false.
	config_json=$(cd -- "$dir" && npm config ls --json </dev/null 2>/dev/null) || config_json=""
	if ! config_problems=$(printf '%s' "$config_json" | python3 -c "$check_config" "$dir/.npmrc"); then
		printf '%s: %s: %s\n' "$PREFIX" "$label" "${config_problems:-npm config ls --json could not be read}" >&2
		problems=$((problems + 1))
	elif [ -n "$config_problems" ]; then
		while IFS= read -r line; do
			printf '%s: %s: %s\n' "$PREFIX" "$label" "$line" >&2
		done <<<"$config_problems"
		problems=$((problems + 1))
	fi

	# Every lockfile entry comes from the registry, or ships inside a registry tarball.
	if ! source_problems=$(python3 -c "$check_sources" "$lockfile" 2>&1); then
		printf '%s: %s: %s\n' "$PREFIX" "$label" "$source_problems" >&2
		problems=$((problems + 1))
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

printf '%s: OK — %d workspace(s) require npm %s, install from the registry only, and every install script has a decision in allowScripts.\n' "$PREFIX" "$examined" "${MIN_NPM%%.*}"
