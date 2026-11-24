#!/usr/bin/env bash
#
# check-npm-policy.sh — hold the repo's npm install policy in the gauntlet.
#
# Run:  npm run check:npm-policy
#   (or: bash scripts/check-npm-policy.sh)
#
# The policy, and why each part exists:
#   - npm at or above the root engines.npm everywhere. npm 12 skips a dependency install script
#     that package.json allowScripts has no decision for, and refuses git and URL dependencies;
#     older npm runs and fetches them. Every workspace declares the same engines.npm, and its
#     .npmrc sets engine-strict=true so an older npm refuses to install at all.
#   - Installs come from the npm registry only. Each .npmrc pins registry to registry.npmjs.org
#     and allow-git/remote/file/directory to none, and every lockfile entry must come from that
#     registry with a sha512 integrity hash, or be bundled inside one that does.
#   - Nothing lets scripts run without a decision: no committed allow-scripts or
#     dangerously-allow-all-scripts line in any spelling (`allow-scripts[]`, `allow_scripts`),
#     and npm must resolve both to empty/false in every workspace.
#   - Every install script has a decision: `npm install-scripts ls` lists nothing undecided.
#   - Deploys get npm from tools/npm, whose lockfile pins its version and integrity, and deploy
#     files may use npm only in the shapes scripts/npm_policy_deploy.py allows.
#
# The environment: `npm run` exports the root's resolved config as npm_config_*, and npm reads
# those ahead of a workspace's .npmrc. The check first fails on any such variable that
# contradicts the policy (the values `npm run` itself exports agree with it), then clears them
# all so each workspace answers for itself.
#
# Three properties of `npm install-scripts ls` shape the last part, each a way it could pass
# having checked nothing: it exits 0 whether or not anything is undecided (so its --json output
# is read), it reports nothing for a workspace with no installed tree (so one without
# node_modules/.package-lock.json is refused), and it does not understand npm workspaces (so it
# runs in every directory holding a tracked package-lock.json, and finding none fails).
#
# The parsing lives in scripts/npm_policy.py. Read-only: it never approves, denies, or installs.

set -u

PREFIX="check-npm-policy"
BOOTSTRAP_DIR="tools/npm"
# The policy's own floor, which no edit to engines.npm can lower: npm 12 is the first that skips
# undecided install scripts and refuses git and URL dependencies by default.
HARD_FLOOR_MAJOR=12

fail() {
	printf '%s: FAIL — %s\n' "$PREFIX" "$1" >&2
	exit 1
}

ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || fail "not inside a git working tree."
cd -- "$ROOT" || exit 1
command -v python3 >/dev/null 2>&1 || fail "python3 is not on PATH; it parses npm output here."
POLICY=(python3 -B "$ROOT/scripts/npm_policy.py") # -B: importing npm_policy_deploy writes no __pycache__
[ -f "$ROOT/scripts/npm_policy.py" ] || fail "scripts/npm_policy.py is missing."

# The environment first, while the inherited npm_config_* are still visible.
if ! env_problems=$("${POLICY[@]}" env); then
	while IFS= read -r line; do
		printf '%s: %s\n' "$PREFIX" "$line" >&2
	done <<<"$env_problems"
	fail "the environment overrides the npm policy; unset those variables."
fi
for var in $(compgen -e); do
	case "$var" in
	npm_config_* | NPM_CONFIG_*) unset "$var" 2>/dev/null || true ;;
	esac
done

MIN_NPM=$("${POLICY[@]}" min-npm package.json) || fail "$MIN_NPM"
[ "${MIN_NPM%%.*}" -ge "$HARD_FLOOR_MAJOR" ] 2>/dev/null || fail "root engines.npm (>=$MIN_NPM) is below npm $HARD_FLOOR_MAJOR, the floor this policy depends on."

npm_version=$(npm --version 2>/dev/null) || fail "npm is not on PATH."
"${POLICY[@]}" version-ok "$npm_version" "$MIN_NPM"
case $? in
0) ;;
1) fail "npm $npm_version is older than the npm $MIN_NPM this repo requires; npm before 12 runs undecided install scripts (npm install -g npm@${MIN_NPM%%.*}, after nvm install for the Node in .nvmrc)." ;;
*) fail "could not compare npm version '$npm_version' with the required '$MIN_NPM'." ;;
esac

problems=0
examined=0
report() {
	printf '%s: %s: %s\n' "$PREFIX" "$1" "$2" >&2
	problems=$((problems + 1))
}

# Deploy paths bootstrap npm from tools/npm rather than fetching it by version.
if ! pinned=$("${POLICY[@]}" bootstrap "$BOOTSTRAP_DIR" "$MIN_NPM"); then
	while IFS= read -r line; do
		report "$BOOTSTRAP_DIR" "$line"
	done <<<"$pinned"
fi
if ! deploy_problems=$(git ls-files -z | "${POLICY[@]}" deploy); then
	while IFS= read -r line; do
		report "deploy" "$line"
	done <<<"$deploy_problems"
fi
# npm prefers npm-shrinkwrap.json over package-lock.json, and this check reads only the latter.
while IFS= read -r file; do
	report "$file" "npm-shrinkwrap.json is not allowed; package-lock.json is the lockfile this policy checks."
done < <(git ls-files -- 'npm-shrinkwrap.json' '*/npm-shrinkwrap.json')

while IFS= read -r lockfile; do
	dir=$(dirname -- "$lockfile")
	label=$dir
	[ "$label" = "." ] && label="(root)"

	if ! sources=$("${POLICY[@]}" sources "$lockfile"); then
		report "$label" "$sources"
	fi
	# tools/npm is the bootstrap: installed by whatever npm the host has, before npm 12 exists
	# there. It gets the source and version checks above, not the workspace policy below.
	[ "$dir" = "$BOOTSTRAP_DIR" ] && continue
	examined=$((examined + 1))

	if ! engines=$("${POLICY[@]}" engines "$dir/package.json" "$MIN_NPM"); then
		report "$label" "$engines"
	fi

	if ! config_json=$(cd -- "$dir" && npm config ls --json </dev/null 2>/dev/null); then
		config_json=""
	fi
	if ! config_problems=$(printf '%s' "$config_json" | "${POLICY[@]}" config "$dir/.npmrc"); then
		while IFS= read -r line; do
			report "$label" "$line"
		done <<<"$config_problems"
	fi

	if [ ! -f "$dir/node_modules/.package-lock.json" ]; then
		report "$label" "no installed tree; run npm ci there first (an uninstalled workspace lists nothing and would read as clean)."
		continue
	fi
	if ! ls_json=$(cd -- "$dir" && npm install-scripts ls --json </dev/null 2>/dev/null); then
		report "$label" "npm install-scripts ls --json failed."
		continue
	fi
	if ! names=$(printf '%s' "$ls_json" | "${POLICY[@]}" parse-ls 2>/dev/null); then
		report "$label" "could not read the npm install-scripts ls --json output."
		continue
	fi
	if [ -n "$names" ]; then
		while IFS= read -r name; do
			report "$label" "$name has an install script with no decision in allowScripts."
			printf '    Review it, then from %s run: npm install-scripts approve %s (or deny %s).\n' "$label" "$name" "$name" >&2
		done <<<"$names"
	fi
done < <(git ls-files -- 'package-lock.json' '*/package-lock.json')

[ "$examined" -gt 0 ] || fail "found no tracked package-lock.json outside $BOOTSTRAP_DIR; the walk examined nothing."
[ "$problems" -eq 0 ] || fail "$problems problem(s) across $examined workspace(s)."

printf '%s: OK — %d workspace(s) require npm %s, install from the registry only, and every install script has a decision; deploys bootstrap npm %s from %s.\n' "$PREFIX" "$examined" "$MIN_NPM" "$pinned" "$BOOTSTRAP_DIR"
