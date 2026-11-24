#!/usr/bin/env bash
# Tests for scripts/check-npm-policy.sh (and scripts/npm_policy.py, which does its parsing) —
# the check that holds the repo's npm install policy in the gauntlet.
#
# Every case runs against a SANDBOX git tree with a stubbed `npm` first on PATH, never the real
# repo or the real registry: the cases need npm to report undecided packages, an old version,
# odd config and failing commands on demand. The stub reads per-directory files a case writes
# (`.stub-ls.json`, `.stub-ls-fail`, `.stub-strict`, `.stub-config.json`, `.stub-config-fail`)
# and `STUB_NPM_VERSION`, and honors exported npm_config_* the way real npm does.
#
# The control case matters as much as the failures: a check that cannot pass is as useless as
# one that cannot fail, and a broken sandbox would make every "it failed" assertion pass for
# the wrong reason.
#
# bash 3.2-safe: no mapfile, no globstar.

set -u

# A suite run from a git hook inherits git's pointers to the outer repository; without this
# the sandbox's `git add` and `git ls-files` would act on the real repo.
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_OBJECT_DIRECTORY \
	GIT_ALTERNATE_OBJECT_DIRECTORIES GIT_COMMON_DIR GIT_NAMESPACE \
	GIT_PREFIX GIT_QUARANTINE_PATH
# The suite itself may run under `npm run`, which exports npm_config_*; the check would read
# them as the environment under test.
for var in $(compgen -e); do
	case "$var" in
	npm_config_* | NPM_CONFIG_*) unset "$var" 2>/dev/null || true ;;
	esac
done

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT="$ROOT/scripts/check-npm-policy.sh"
HELPER="$ROOT/scripts/npm_policy.py"

pass=0
fail=0
ok() {
	pass=$((pass + 1))
	printf '  ok    %s\n' "$1"
}
bad() {
	fail=$((fail + 1))
	printf '  FAIL  %s\n' "$1"
}

# The template form, not `mktemp -t`: BSD mktemp appends its own suffix after -t's template,
# so the name would never match the cleanup guard below and the sandbox would leak.
SANDBOX="$(mktemp -d "${TMPDIR:-/tmp}/npm-policy.XXXXXX")"
if [ -z "$SANDBOX" ] || [ ! -d "$SANDBOX" ]; then
	echo "mktemp failed — cannot run tests" >&2
	exit 1
fi
# Guarded per the destructive-deletion rules: non-empty, and matching the template this test
# created. Kept inline in each trap, since a function reached only through `trap` looks
# uninvoked to shellcheck. INT and TERM clean up and then exit, so a signal cannot resume the
# script against a deleted sandbox.
trap 'case "$SANDBOX" in */npm-policy.??????) rm -rf -- "${SANDBOX:?}" ;; esac' EXIT
trap 'case "$SANDBOX" in */npm-policy.??????) rm -rf -- "${SANDBOX:?}" ;; esac; exit 130' INT
trap 'case "$SANDBOX" in */npm-policy.??????) rm -rf -- "${SANDBOX:?}" ;; esac; exit 143' TERM

mkdir -p "$SANDBOX/bin"
cat >"$SANDBOX/bin/npm" <<'STUB'
#!/usr/bin/env bash
# Stub npm. The check gives every npm call </dev/null, so the stub never reads stdin.
case "${1:-}" in
--version)
	printf '%s\n' "${STUB_NPM_VERSION:-12.2.2}"
	;;
config)
	if [ "${2:-}" = "ls" ] && [ "${3:-}" = "--json" ]; then
		[ -f .stub-config-fail ] && exit 1
		# Resolved config: npm 12's values for this repo's .npmrc, then this directory's
		# overrides, then exported npm_config_* in either case, which real npm reads ahead of
		# the project .npmrc.
		python3 -c '
import json, os
cfg = {"engine-strict": True, "registry": "https://registry.npmjs.org/",
       "dangerously-allow-all-scripts": False, "allow-scripts": [""], "allow-git": "none",
       "allow-remote": "none", "allow-file": "none", "allow-directory": "none"}
if os.path.exists(".stub-strict"):
    text = open(".stub-strict").read().strip()
    if text: cfg["engine-strict"] = text == "true"
    else: cfg.pop("engine-strict")
if os.path.exists(".stub-config.json"):
    cfg.update(json.load(open(".stub-config.json")))
for name, value in os.environ.items():
    if name.lower() == "npm_config_engine_strict": cfg["engine-strict"] = value == "true"
print(json.dumps(cfg))
'
		exit 0
	fi
	exit 1
	;;
install-scripts)
	if [ "${2:-}" = "ls" ] && [ "${3:-}" = "--json" ]; then
		[ -f .stub-ls-fail ] && exit 1
		if [ -f .stub-ls.json ]; then cat .stub-ls.json; else printf '{\n  "allowScripts": []\n}\n'; fi
		exit 0
	fi
	exit 1
	;;
*)
	exit 1
	;;
esac
STUB
chmod +x "$SANDBOX/bin/npm"
export PATH="$SANDBOX/bin:$PATH"

GOOD_NPMRC='engine-strict=true
registry=https://registry.npmjs.org/
allow-git=none
allow-remote=none
allow-file=none
allow-directory=none'
REG_LOCK='{"lockfileVersion":3,"packages":{"":{},"node_modules/a":{"version":"1.0.0","resolved":"https://registry.npmjs.org/a/-/a-1.0.0.tgz","integrity":"sha512-AAAA"},"node_modules/a/node_modules/b":{"version":"1.0.0","inBundle":true}}}'

# A tree with three installed, policy-clean workspaces, a tools/npm bootstrap pinning npm
# 12.2.2, and a Dockerfile that installs with it.
build_sandbox() {
	rm -rf -- "${SANDBOX:?}/tree"
	mkdir -p "$SANDBOX/tree/scripts" "$SANDBOX/tree/apps/api" "$SANDBOX/tree/apps/web" "$SANDBOX/tree/tools/npm"
	cp -- "$SCRIPT" "$SANDBOX/tree/scripts/check-npm-policy.sh"
	cp -- "$HELPER" "$SANDBOX/tree/scripts/npm_policy.py"
	(
		cd -- "$SANDBOX/tree" || exit 1
		git init -q .
		for d in . apps/api apps/web; do
			printf '%s\n' "$REG_LOCK" >"$d/package-lock.json"
			printf '%s\n' "$GOOD_NPMRC" >"$d/.npmrc"
			printf '{"engines":{"node":">=26.0.0","npm":">=12.0.0"}}\n' >"$d/package.json"
			mkdir -p "$d/node_modules"
			printf '{}\n' >"$d/node_modules/.package-lock.json"
		done
		printf '{"private":true,"dependencies":{"npm":"12.2.2"}}\n' >tools/npm/package.json
		printf '{"lockfileVersion":3,"packages":{"":{},"node_modules/npm":{"version":"12.2.2","resolved":"https://registry.npmjs.org/npm/-/npm-12.2.2.tgz","integrity":"sha512-BBBB"},"node_modules/npm/node_modules/semver":{"version":"7.0.0","inBundle":true}}}\n' >tools/npm/package-lock.json
		printf 'registry=https://registry.npmjs.org/\nallow-git=none\n' >tools/npm/.npmrc
		printf 'FROM node:26-alpine\nRUN cd /app/tools/npm && npm ci\nRUN /app/tools/npm/node_modules/.bin/npm ci\n' >apps/api/Dockerfile
		git add -- package-lock.json apps/api/package-lock.json apps/web/package-lock.json tools/npm/package-lock.json apps/api/Dockerfile
	)
}

run_check() { (cd -- "$SANDBOX/tree" && bash scripts/check-npm-policy.sh 2>&1); }
run_env() { (cd -- "$SANDBOX/tree" && env "$@" bash scripts/check-npm-policy.sh 2>&1); }
expect_fail() { # <description> <expected substring> ; reads $out and $rc
	if [ "$rc" -eq 0 ]; then bad "$1 passed"; else ok "$1 fails"; fi
	case "$out" in *"$2"*) ok "  …and says: $2" ;; *) bad "$1: wrong reason: $out" ;; esac
}

echo "check-npm-policy — a policy-clean tree passes (control)"
build_sandbox
if out="$(run_check)"; then ok "exits 0 when everything holds"; else bad "clean tree failed: $out"; fi
case "$out" in *"OK — 3 workspace(s) require npm 12.0.0"*"bootstrap npm 12.2.2 from tools/npm"*) ok "counts three workspaces and names the bootstrap" ;; *) bad "wrong summary: $out" ;; esac
out="$(run_env npm_config_engine_strict=true npm_config_allow_file=none npm_config_allow_directory=none)"
rc=$?
if [ "$rc" -eq 0 ]; then ok "the variables npm run exports (they agree with the policy) pass"; else bad "npm run's own exports failed: $out"; fi

echo
echo "check-npm-policy — every required .npmrc setting is enforced, committed and resolved"
for setting in engine-strict=true registry=https://registry.npmjs.org/ allow-git=none allow-remote=none allow-file=none allow-directory=none; do
	key=${setting%%=*}
	build_sandbox
	printf '%s\n' "$GOOD_NPMRC" | grep -v -e "^$key=" >"$SANDBOX/tree/apps/web/.npmrc"
	out="$(run_check)"
	rc=$?
	expect_fail "an .npmrc without $key" "apps/web: apps/web/.npmrc does not set $setting"
	build_sandbox
	printf '{"%s": "something-else"}\n' "$key" >"$SANDBOX/tree/apps/api/.stub-config.json"
	out="$(run_check)"
	rc=$?
	expect_fail "$key resolving to another value" "apps/api: apps/api/.npmrc sets $setting but npm resolves it to 'something-else'"
done

echo
echo "check-npm-policy — anything that lets scripts run without a decision fails, in any spelling"
for line in 'dangerously-allow-all-scripts=true' 'allow-scripts=esbuild' 'allow-scripts[]=esbuild' 'ALLOW_SCRIPTS=esbuild' 'Dangerously_Allow_All_Scripts=true'; do
	build_sandbox
	printf '%s\n' "$line" >>"$SANDBOX/tree/apps/web/.npmrc"
	out="$(run_check)"
	rc=$?
	expect_fail "a committed '$line'" "apps/web: apps/web/.npmrc sets ${line%%=*}, which lets install scripts run"
done
build_sandbox
printf '{"allow-scripts": ["esbuild"]}\n' >"$SANDBOX/tree/apps/api/.stub-config.json"
out="$(run_check)"
rc=$?
expect_fail "allow-scripts resolving to a package (a user-level .npmrc)" "apps/api: npm resolves allow-scripts to ['esbuild']"
build_sandbox
printf '{"dangerously-allow-all-scripts": true}\n' >"$SANDBOX/tree/apps/api/.stub-config.json"
out="$(run_check)"
rc=$?
expect_fail "dangerously-allow-all-scripts resolving to true" "apps/api: npm resolves dangerously-allow-all-scripts to True"

echo
echo "check-npm-policy — anything that changes where packages come from fails"
for line in '@evil:registry=https://evil.example/' 'replace-registry-host=never'; do
	build_sandbox
	printf '%s\n' "$line" >>"$SANDBOX/tree/apps/api/.npmrc"
	out="$(run_check)"
	rc=$?
	expect_fail "a committed '$line'" "apps/api: apps/api/.npmrc sets ${line%%=*}, which changes where packages are fetched from"
done

echo
echo "check-npm-policy — an environment that contradicts the policy fails, in either case"
build_sandbox
out="$(run_env NPM_CONFIG_DANGEROUSLY_ALLOW_ALL_SCRIPTS=true)"
rc=$?
expect_fail "NPM_CONFIG_DANGEROUSLY_ALLOW_ALL_SCRIPTS=true" "environment variable NPM_CONFIG_DANGEROUSLY_ALLOW_ALL_SCRIPTS='true' overrides the npm policy"
build_sandbox
out="$(run_env npm_config_engine_strict=false)"
rc=$?
expect_fail "npm_config_engine_strict=false" "environment variable npm_config_engine_strict='false' overrides the npm policy"
build_sandbox
out="$(run_env npm_config_registry=https://evil.example/)"
rc=$?
expect_fail "a registry override in the environment" "environment variable npm_config_registry="
build_sandbox
out="$(run_env npm_config_allow_scripts=esbuild)"
rc=$?
expect_fail "npm_config_allow_scripts=esbuild" "environment variable npm_config_allow_scripts='esbuild'"
# The regression this guards: an inherited npm_config_engine_strict=true (what `npm run`
# exports from the root) must not mask a workspace whose own value is false, in either case.
for name in npm_config_engine_strict NPM_CONFIG_ENGINE_STRICT; do
	build_sandbox
	printf 'false\n' >"$SANDBOX/tree/apps/web/.stub-strict"
	out="$(run_env "$name=true")"
	rc=$?
	expect_fail "an inherited $name=true over a workspace resolving false" "apps/web: apps/web/.npmrc sets engine-strict=true but npm resolves it to False"
done

echo
echo "check-npm-policy — every workspace requires the root's npm"
build_sandbox
printf '{"engines":{"node":">=26.0.0"}}\n' >"$SANDBOX/tree/apps/api/package.json"
out="$(run_check)"
rc=$?
expect_fail "a package.json without engines.npm" 'apps/api: apps/api/package.json does not declare engines.npm ">=12.0.0"'
for spec in '>=11.20.0' '>=12.0.0 || >=1.0.0' '^12.0.0'; do
	build_sandbox
	printf '{"engines":{"npm":"%s"}}\n' "$spec" >"$SANDBOX/tree/apps/web/package.json"
	out="$(run_check)"
	rc=$?
	expect_fail "engines.npm '$spec'" "apps/web: apps/web/package.json does not declare engines.npm"
done
build_sandbox
printf '{"engines":{"node":">=26.0.0"}}\n' >"$SANDBOX/tree/package.json"
out="$(run_check)"
rc=$?
expect_fail "a root package.json without engines.npm" 'package.json does not declare engines.npm as ">=X.Y.Z"'

echo
echo "check-npm-policy — every lockfile entry comes from the registry with integrity"
for case_ in \
	'git dependency|{"lockfileVersion":3,"packages":{"":{},"node_modules/a":{"resolved":"git+ssh://git@github.com/evil/a.git#abc","integrity":"sha512-A"}}}|node_modules/a (git+ssh://' \
	'lookalike host|{"lockfileVersion":3,"packages":{"":{},"node_modules/a":{"resolved":"https://registry.npmjs.org.evil.example/a.tgz","integrity":"sha512-A"}}}|node_modules/a (https://registry.npmjs.org.evil.example/' \
	'linked dependency|{"lockfileVersion":3,"packages":{"":{},"node_modules/a":{"link":true}}}|node_modules/a (no registry source)' \
	'entry without integrity|{"lockfileVersion":3,"packages":{"":{},"node_modules/a":{"resolved":"https://registry.npmjs.org/a/-/a-1.0.0.tgz"}}}|node_modules/a (no sha512 integrity)' \
	'bundled entry with no registry parent|{"lockfileVersion":3,"packages":{"":{},"node_modules/x":{"inBundle":true}}}|node_modules/x (bundled in nothing' \
	'lockfileVersion 1|{"lockfileVersion":1,"dependencies":{"a":{"version":"git+ssh://x"}}}|is not lockfileVersion 2 or later' \
	'no packages map|{"lockfileVersion":3}|has no packages map with a root entry' \
	'packages map without a root entry|{"lockfileVersion":3,"packages":{}}|has no packages map with a root entry'; do
	name=${case_%%|*}
	rest=${case_#*|}
	lock=${rest%%|*}
	want=${rest#*|}
	build_sandbox
	printf '%s\n' "$lock" >"$SANDBOX/tree/apps/api/package-lock.json"
	out="$(run_check)"
	rc=$?
	expect_fail "a lockfile with a $name" "$want"
done

echo
echo "check-npm-policy — deploys bootstrap npm from tools/npm"
build_sandbox
printf '{"private":true,"dependencies":{"npm":"12.3.0"}}\n' >"$SANDBOX/tree/tools/npm/package.json"
out="$(run_check)"
rc=$?
expect_fail "a bootstrap pin its lockfile disagrees with" "locks npm '12.2.2', but tools/npm/package.json pins 12.3.0"
build_sandbox
printf '{"private":true,"dependencies":{"npm":"^12.2.2"}}\n' >"$SANDBOX/tree/tools/npm/package.json"
out="$(run_check)"
rc=$?
expect_fail "a bootstrap range instead of an exact pin" "tools/npm/package.json must pin npm to an exact version"
build_sandbox
printf '{"private":true,"dependencies":{"npm":"11.20.0"}}\n' >"$SANDBOX/tree/tools/npm/package.json"
printf '{"lockfileVersion":3,"packages":{"":{},"node_modules/npm":{"version":"11.20.0","resolved":"https://registry.npmjs.org/npm/-/npm-11.20.0.tgz","integrity":"sha512-C"}}}\n' >"$SANDBOX/tree/tools/npm/package-lock.json"
out="$(run_check)"
rc=$?
expect_fail "a bootstrap npm below engines.npm" "pins npm 11.20.0, below the 12.0.0 that engines.npm requires"
build_sandbox
printf '{"lockfileVersion":3,"packages":{"":{},"node_modules/npm":{"version":"12.2.2","resolved":"https://evil.example/npm.tgz","integrity":"sha512-B"}}}\n' >"$SANDBOX/tree/tools/npm/package-lock.json"
out="$(run_check)"
rc=$?
expect_fail "a bootstrap lockfile from outside the registry" "tools/npm: tools/npm/package-lock.json installs from outside the npm registry"
build_sandbox
printf 'FROM node:26-alpine\nRUN npm install -g npm@12.2.2\n' >"$SANDBOX/tree/apps/api/Dockerfile"
out="$(run_check)"
rc=$?
expect_fail "a Dockerfile that fetches npm by version" "apps/api/Dockerfile:2 fetches npm itself"
build_sandbox
printf '{"installCommand":"npx -y npm@12.2.2 install"}\n' >"$SANDBOX/tree/vercel.json"
(cd -- "$SANDBOX/tree" && git add -- vercel.json)
out="$(run_check)"
rc=$?
expect_fail "a vercel.json that fetches npm by version" "vercel.json installCommand fetches npm itself"

for line in 'RUN npm install -g npm@latest' 'RUN npm i -g npm@^12' 'RUN npm install -g npm' 'RUN npx -y npm install'; do
	build_sandbox
	printf '%s\n' "$line" >>"$SANDBOX/tree/apps/api/Dockerfile"
	out="$(run_check)"
	rc=$?
	expect_fail "a Dockerfile line '$line'" "apps/api/Dockerfile:4 fetches npm itself"
done
build_sandbox
printf 'FROM node:26-alpine\nRUN npm ci\n' >"$SANDBOX/tree/apps/api/Dockerfile"
out="$(run_check)"
rc=$?
expect_fail "a Dockerfile installing with the image's npm" "apps/api/Dockerfile:2 installs dependencies with an npm other than tools/npm/node_modules/.bin/npm"
build_sandbox
printf 'RUN corepack prepare pnpm@9 --activate\n' >>"$SANDBOX/tree/apps/api/Dockerfile"
if out="$(run_check)"; then ok "pnpm@9 is not mistaken for npm (control)"; else bad "pnpm@9 was flagged: $out"; fi
echo
echo "check-npm-policy — deploy files are parsed: every npm call is judged on its own"
deploy_case() { # <expectation: fail|pass> <expected substring or ''> <Dockerfile line>
	build_sandbox
	printf '%s\n' "$3" >>"$SANDBOX/tree/apps/api/Dockerfile"
	out="$(run_check)"
	rc=$?
	if [ "$1" = pass ]; then
		if [ "$rc" -eq 0 ]; then ok "'$3' passes (control)"; else bad "'$3' was flagged: $out"; fi
	else
		expect_fail "a Dockerfile line '$3'" "$2"
	fi
}
for line in 'RUN npm -g install npm' 'RUN npm install npm' 'RUN npm install -g --no-audit npm' 'RUN npm i --location=global npm' 'RUN npx --yes --package=npm npm --version' 'RUN npx -- npm install' 'RUN corepack prepare npm@12 --activate'; do
	deploy_case fail "apps/api/Dockerfile:4 fetches npm itself" "$line"
done
for line in 'RUN npm --prefix apps/api ci' 'RUN npm -w apps/api ci' "$(printf 'RUN npm\tci')" 'RUN ["npm", "ci"]' 'RUN npm ci;' 'RUN npm ci&&npm run build' 'RUN sh -c "npm ci"' 'RUN cd /app/tools/npm && cd /app && npm ci'; do
	deploy_case fail "apps/api/Dockerfile:4 installs dependencies with an npm other than" "$line"
done
deploy_case fail "ENV npm_config_dangerously_allow_all_scripts='true' overrides the npm policy" 'ENV npm_config_dangerously_allow_all_scripts=true'
deploy_case fail "ENV NPM_CONFIG_REGISTRY='https://evil.example/' overrides the npm policy" 'ENV NPM_CONFIG_REGISTRY https://evil.example/'
deploy_case fail "ARG npm_config_allow_scripts lets" 'ARG npm_config_allow_scripts'
deploy_case fail "sets npm_config_dangerously_allow_all_scripts='true' overrides the npm policy" 'RUN npm_config_dangerously_allow_all_scripts=true /app/tools/npm/node_modules/.bin/npm ci'
deploy_case fail "passes --dangerously-allow-all-scripts" 'RUN /app/tools/npm/node_modules/.bin/npm ci --dangerously-allow-all-scripts'
deploy_case fail "passes --registry, which changes where packages are fetched from" 'RUN /app/tools/npm/node_modules/.bin/npm ci --registry=https://evil.example/'
deploy_case fail "passes --no-engine-strict" 'RUN /app/tools/npm/node_modules/.bin/npm ci --no-engine-strict'
for line in 'RUN pnpm install --frozen-lockfile' 'RUN /app/tools/npm/node_modules/.bin/npm run build' 'RUN npm run build' 'RUN npm install-scripts ls' 'RUN /app/tools/npm/node_modules/.bin/npm ci --registry=https://registry.npmjs.org/' 'ENV npm_config_engine_strict=true' '# RUN npm ci in a comment is not a command'; do
	deploy_case pass "" "$line"
done
build_sandbox
printf '{"installCommand":"(cd ../../tools/npm && npm ci) && ../../tools/npm/node_modules/.bin/npm ci"}\n' >"$SANDBOX/tree/vercel.json"
(cd -- "$SANDBOX/tree" && git add -- vercel.json)
if out="$(run_check)"; then ok "vercel.json installing with the bootstrap passes (control)"; else bad "the bootstrap installCommand was flagged: $out"; fi
build_sandbox
printf '{"installCommand":"(cd ../../tools/npm && npm ci) && npm ci"}\n' >"$SANDBOX/tree/vercel.json"
(cd -- "$SANDBOX/tree" && git add -- vercel.json)
out="$(run_check)"
rc=$?
expect_fail "an install after leaving the tools/npm subshell" "vercel.json installCommand installs dependencies with an npm other than"
deploy_case fail "apps/api/Dockerfile:4 fetches npm itself" 'RUN npx -p npm@12 semver --help'
build_sandbox
printf 'FROM node:26-alpine\nRUN npm ci\n' >"$SANDBOX/tree/apps/api/Dockerfile.prod"
(cd -- "$SANDBOX/tree" && git add -- apps/api/Dockerfile.prod)
out="$(run_check)"
rc=$?
expect_fail "a Dockerfile.prod installing with the host npm" "apps/api/Dockerfile.prod:2 installs dependencies with an npm other than"
build_sandbox
printf '{"installCommand":"npm ci"}\n' >"$SANDBOX/tree/vercel.json"
(cd -- "$SANDBOX/tree" && git add -- vercel.json)
out="$(run_check)"
rc=$?
expect_fail "a vercel.json installing with the host npm" "vercel.json installCommand installs dependencies with an npm other than"
build_sandbox
printf '{"build":{"env":{"NPM_CONFIG_DANGEROUSLY_ALLOW_ALL_SCRIPTS":"true"}}}\n' >"$SANDBOX/tree/vercel.json"
(cd -- "$SANDBOX/tree" && git add -- vercel.json)
out="$(run_check)"
rc=$?
expect_fail "a vercel.json env that lets scripts run" "vercel.json env NPM_CONFIG_DANGEROUSLY_ALLOW_ALL_SCRIPTS='true' overrides the npm policy"
build_sandbox
printf 'FROM node:26-alpine\nRUN npm ci\n' >"$SANDBOX/tree/apps/api/Containerfile"
(cd -- "$SANDBOX/tree" && git add -- apps/api/Containerfile)
out="$(run_check)"
rc=$?
expect_fail "a Containerfile installing with the host npm" "apps/api/Containerfile:2 installs dependencies with an npm other than"
build_sandbox
mkdir -p "$SANDBOX/tree/.railway"
printf 'FROM node:26-alpine\nRUN npm ci\n' >"$SANDBOX/tree/apps/api/build.recipe"
printf "export default { build: { dockerfilePath: 'apps/api/build.recipe' } }\n" >"$SANDBOX/tree/.railway/railway.ts"
(cd -- "$SANDBOX/tree" && git add -- apps/api/build.recipe .railway/railway.ts)
out="$(run_check)"
rc=$?
expect_fail "the file railway.ts builds from, whatever its name" "apps/api/build.recipe:2 installs dependencies with an npm other than"
build_sandbox
mkdir -p "$SANDBOX/tree/.railway"
printf "export default { build: { dockerfilePath: 'apps/api/Missing' } }\n" >"$SANDBOX/tree/.railway/railway.ts"
(cd -- "$SANDBOX/tree" && git add -- .railway/railway.ts)
out="$(run_check)"
rc=$?
expect_fail "a railway.ts building from an untracked file" ".railway/railway.ts builds from apps/api/Missing, which is not a tracked file"
build_sandbox
printf 'allow-scripts.esbuild=true\n' >>"$SANDBOX/tree/apps/web/.npmrc"
out="$(run_check)"
rc=$?
expect_fail "a dotted allow-scripts.<pkg> line" "apps/web: apps/web/.npmrc sets allow-scripts.esbuild, which lets install scripts run"

build_sandbox
printf 'allow-git=none\n' >"$SANDBOX/tree/tools/npm/.npmrc"
out="$(run_check)"
rc=$?
expect_fail "a bootstrap .npmrc without the registry pin" "tools/npm: tools/npm/.npmrc does not set registry=https://registry.npmjs.org/"
build_sandbox
printf 'dangerously-allow-all-scripts=true\n' >>"$SANDBOX/tree/tools/npm/.npmrc"
out="$(run_check)"
rc=$?
expect_fail "a bootstrap .npmrc that lets scripts run" "tools/npm: tools/npm/.npmrc sets dangerously-allow-all-scripts"
build_sandbox
printf '{"lockfileVersion":3,"packages":{"":{},"node_modules/npm":{"version":"12.2.2","resolved":"https://registry.npmjs.org/npm/-/npm-12.2.2.tgz","integrity":"sha512-B","hasInstallScript":true}}}\n' >"$SANDBOX/tree/tools/npm/package-lock.json"
out="$(run_check)"
rc=$?
expect_fail "a bootstrap with an install script" "has entries with install scripts (node_modules/npm)"
build_sandbox
printf '{}\n' >"$SANDBOX/tree/apps/api/npm-shrinkwrap.json"
(cd -- "$SANDBOX/tree" && git add -- apps/api/npm-shrinkwrap.json)
out="$(run_check)"
rc=$?
expect_fail "a tracked npm-shrinkwrap.json" "apps/api/npm-shrinkwrap.json: npm-shrinkwrap.json is not allowed"
build_sandbox
printf '{"@evil:registry": "https://evil.example/"}\n' >"$SANDBOX/tree/apps/web/.stub-config.json"
out="$(run_check)"
rc=$?
expect_fail "a scoped registry in the resolved config" "apps/web: npm resolves @evil:registry to 'https://evil.example/'"
build_sandbox
printf '{"replace-registry-host": "never"}\n' >"$SANDBOX/tree/apps/web/.stub-config.json"
out="$(run_check)"
rc=$?
expect_fail "replace-registry-host resolved to never" "apps/web: npm resolves replace-registry-host to 'never'"
build_sandbox
printf '{"lockfileVersion":3,"packages":{"":{},"node_modules/a":{"resolved":["x"],"integrity":"sha512-A"}}}\n' >"$SANDBOX/tree/apps/api/package-lock.json"
out="$(run_check)"
rc=$?
expect_fail "a lockfile entry whose resolved is not a string" "node_modules/a (resolved is not a string)"
build_sandbox
for d in . apps/api apps/web; do printf '{"engines":{"npm":">=11.0.0"}}\n' >"$SANDBOX/tree/$d/package.json"; done
out="$(run_env STUB_NPM_VERSION=11.20.0)"
rc=$?
expect_fail "lowering every engines.npm below 12" "root engines.npm (>=11.0.0) is below npm 12"

echo
echo "check-npm-policy — an undecided install script fails and is named"
build_sandbox
printf '{"allowScripts":[{"name":"core-js","changes":[{"key":"core-js@3.51.0","change":"pending"}]}]}\n' >"$SANDBOX/tree/apps/web/.stub-ls.json"
out="$(run_check)"
rc=$?
expect_fail "a pending package" "apps/web: core-js has an install script with no decision"
case "$out" in *"npm install-scripts approve core-js (or deny core-js)"*) ok "prints the command that records a decision" ;; *) bad "no remedy printed: $out" ;; esac
build_sandbox
printf '{"allowScripts":[{"name":"sharp","changes":[]},{"name":"canvas","changes":[]}]}\n' >"$SANDBOX/tree/apps/api/.stub-ls.json"
out="$(run_check)"
rc=$?
expect_fail "two undecided packages" "approve sharp (or deny sharp)"
case "$out" in *"approve canvas (or deny canvas)"*) ok "prints a remedy for each package" ;; *) bad "a package got no remedy: $out" ;; esac

echo
echo "check-npm-policy — the ways it could pass having checked nothing all fail closed"
build_sandbox
rm -rf -- "${SANDBOX:?}/tree/apps/api/node_modules"
out="$(run_check)"
rc=$?
expect_fail "a workspace with no installed tree" "apps/api: no installed tree"
build_sandbox
out="$(run_env STUB_NPM_VERSION=11.20.0)"
rc=$?
expect_fail "npm 11.20.0" "npm 11.20.0 is older than the npm 12.0.0 this repo requires"
build_sandbox
out="$(run_env STUB_NPM_VERSION=garbage)"
rc=$?
expect_fail "an unreadable npm version" "could not compare npm version 'garbage'"
for shape in 'not json' '{"something":"else"}' '{"allowScripts":{"esbuild":false}}' '{"allowScripts":{}}' '{"allowScripts":[{"changes":[]}]}' '{"allowScripts":[{"name":"","changes":[]}]}'; do
	build_sandbox
	printf '%s\n' "$shape" >"$SANDBOX/tree/apps/api/.stub-ls.json"
	out="$(run_check)"
	rc=$?
	expect_fail "install-scripts output '$shape'" "apps/api: could not read the npm install-scripts ls --json output"
done
build_sandbox
: >"$SANDBOX/tree/apps/api/.stub-ls-fail"
out="$(run_check)"
rc=$?
expect_fail "a failing npm install-scripts ls" "apps/api: npm install-scripts ls --json failed"
build_sandbox
: >"$SANDBOX/tree/apps/api/.stub-config-fail"
out="$(run_check)"
rc=$?
expect_fail "a failing npm config ls" "apps/api: npm config ls --json could not be read"
build_sandbox
(cd -- "$SANDBOX/tree" && git rm -q --cached -- package-lock.json apps/api/package-lock.json apps/web/package-lock.json)
out="$(run_check)"
rc=$?
expect_fail "a tree whose only lockfile is the bootstrap's" "examined nothing"

echo
echo "check-npm-policy — recording the decision turns it green again"
build_sandbox
printf '{"allowScripts":[{"name":"esbuild","changes":[]}]}\n' >"$SANDBOX/tree/apps/api/.stub-ls.json"
if run_check >/dev/null; then bad "undecided esbuild passed"; else ok "undecided esbuild fails"; fi
rm -f -- "$SANDBOX/tree/apps/api/.stub-ls.json"
if out="$(run_check)"; then ok "after the decision is recorded, the same tree passes"; else bad "decided tree still failed: $out"; fi

echo
echo "=============================================================="
if [ "$fail" -eq 0 ]; then
	echo "npm-policy.test.sh: OK — $pass/$pass assertions passed."
	exit 0
fi
echo "npm-policy.test.sh: FAILED — $fail of $((pass + fail)) assertions failed." >&2
exit 1
