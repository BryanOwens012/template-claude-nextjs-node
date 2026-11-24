#!/usr/bin/env bash
# Tests for scripts/check-install-scripts.sh — the check that every dependency install
# script has a decision recorded in its workspace's allowScripts.
#
# Every case runs against a SANDBOX git tree with a stubbed `npm` first on PATH, never the
# real repo or the real registry: the cases need npm to report unreviewed packages, an old
# version, broken output and a failing command on demand. The stub reads per-directory
# files the case writes (`.stub-ls.json`, `.stub-ls-fail`, `.stub-strict`) and `STUB_NPM_VERSION`.
#
# The control case matters as much as the failures: a check that cannot pass is as useless
# as one that cannot fail, and a broken sandbox would make every "it failed" assertion pass
# for the wrong reason.
#
# bash 3.2-safe: no mapfile, no globstar.

set -u

# A suite run from a git hook inherits git's pointers to the outer repository; without this
# the sandbox's `git add` and `git ls-files` would act on the real repo.
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_OBJECT_DIRECTORY \
	GIT_ALTERNATE_OBJECT_DIRECTORIES GIT_COMMON_DIR GIT_NAMESPACE \
	GIT_PREFIX GIT_QUARANTINE_PATH

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT="$ROOT/scripts/check-install-scripts.sh"

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

SANDBOX="$(mktemp -d -t install-scripts.XXXXXX)"
if [ -z "$SANDBOX" ] || [ ! -d "$SANDBOX" ]; then
	echo "mktemp failed — cannot run tests" >&2
	exit 1
fi
# Guarded per the destructive-deletion rules: non-empty, and matching the template this test
# created. Kept inline in each trap, since a function reached only through `trap` looks
# uninvoked to shellcheck. INT and TERM clean up and then exit, so a signal cannot resume the
# script against a deleted sandbox.
trap 'case "$SANDBOX" in */install-scripts.??????) rm -rf -- "${SANDBOX:?}" ;; esac' EXIT
trap 'case "$SANDBOX" in */install-scripts.??????) rm -rf -- "${SANDBOX:?}" ;; esac; exit 130' INT
trap 'case "$SANDBOX" in */install-scripts.??????) rm -rf -- "${SANDBOX:?}" ;; esac; exit 143' TERM

mkdir -p "$SANDBOX/bin"
cat >"$SANDBOX/bin/npm" <<'STUB'
#!/usr/bin/env bash
# Stub npm. The check gives every npm call </dev/null, so the stub never reads stdin.
case "${1:-}" in
--version)
	printf '%s\n' "${STUB_NPM_VERSION:-11.20.0}"
	;;
config)
	if [ "${2:-}" = "get" ] && [ "${3:-}" = "strict-allow-scripts" ]; then
		# Real npm reads an exported npm_config_* ahead of the project .npmrc; so does the stub.
		if [ -n "${npm_config_strict_allow_scripts:-}" ]; then
			printf '%s\n' "$npm_config_strict_allow_scripts"
		elif [ -f .stub-strict ]; then cat .stub-strict; else printf 'true\n'; fi
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

# A tree with three installed workspaces, all reviewed.
build_sandbox() {
	rm -rf -- "${SANDBOX:?}/tree"
	mkdir -p "$SANDBOX/tree/scripts" "$SANDBOX/tree/apps/api" "$SANDBOX/tree/apps/web"
	cp -- "$SCRIPT" "$SANDBOX/tree/scripts/check-install-scripts.sh"
	(
		cd -- "$SANDBOX/tree" || exit 1
		git init -q .
		for d in . apps/api apps/web; do
			printf '{}\n' >"$d/package-lock.json"
			printf 'strict-allow-scripts=true\n' >"$d/.npmrc"
			mkdir -p "$d/node_modules"
			printf '{}\n' >"$d/node_modules/.package-lock.json"
		done
		git add -- package-lock.json apps/api/package-lock.json apps/web/package-lock.json
	)
}

run_check() { (cd -- "$SANDBOX/tree" && bash scripts/check-install-scripts.sh 2>&1); }

echo "check-install-scripts — a fully reviewed tree passes (control)"
build_sandbox
if out="$(run_check)"; then ok "exits 0 when nothing is unreviewed"; else bad "reviewed tree failed: $out"; fi
case "$out" in *"OK — 3 workspace(s)"*) ok "counts the three workspaces it examined" ;; *) bad "wrong count: $out" ;; esac

echo
echo "check-install-scripts — a workspace that would still run undecided scripts fails"
build_sandbox
rm -f -- "$SANDBOX/tree/apps/web/.npmrc"
if out="$(run_check)"; then bad "a workspace with no .npmrc passed"; else ok "a workspace whose .npmrc lacks strict-allow-scripts fails"; fi
case "$out" in *"apps/web: apps/web/.npmrc does not set strict-allow-scripts=true"*) ok "names the workspace and its .npmrc" ;; *) bad "wrong reason: $out" ;; esac

build_sandbox
printf 'strict-allow-scripts=false\n' >"$SANDBOX/tree/apps/api/.npmrc"
if out="$(run_check)"; then bad "strict-allow-scripts=false passed"; else ok "an .npmrc that sets it to false fails"; fi

build_sandbox
printf 'false\n' >"$SANDBOX/tree/apps/api/.stub-strict"
if out="$(run_check)"; then bad "a line npm resolves to false passed"; else ok "an .npmrc line that npm resolves to false fails"; fi
case "$out" in *"apps/api: apps/api/.npmrc sets strict-allow-scripts=true but npm resolves it to false"*) ok "says a later setting overrides it" ;; *) bad "wrong reason: $out" ;; esac

build_sandbox
: >"$SANDBOX/tree/.stub-strict"
if out="$(run_check)"; then bad "an unresolved strict-allow-scripts passed"; else ok "a setting npm resolves to nothing fails"; fi
case "$out" in *"(root): ./.npmrc sets strict-allow-scripts=true but npm resolves it to unset"*) ok "reports the root workspace as unset" ;; *) bad "wrong reason: $out" ;; esac

# The regression this guards: `npm run` exports the root's npm_config_strict_allow_scripts,
# which would otherwise make every workspace report the root's value instead of its own.
build_sandbox
printf 'false\n' >"$SANDBOX/tree/apps/web/.stub-strict"
if out="$(cd -- "$SANDBOX/tree" && npm_config_strict_allow_scripts=true bash scripts/check-install-scripts.sh 2>&1)"; then
	bad "an inherited npm_config_strict_allow_scripts masked the workspace's own value"
else
	ok "an inherited npm_config_* does not mask a workspace's own value"
fi
case "$out" in *"apps/web: apps/web/.npmrc sets strict-allow-scripts=true but npm resolves it to false"*) ok "reads the web workspace's own value" ;; *) bad "wrong reason: $out" ;; esac

echo
echo "check-install-scripts — an unreviewed install script fails and is named"
build_sandbox
printf '{"allowScripts":[{"name":"core-js","changes":[{"key":"core-js@3.51.0","change":"pending"}]}]}\n' >"$SANDBOX/tree/apps/web/.stub-ls.json"
if out="$(run_check)"; then bad "an unreviewed package passed"; else ok "a pending package fails the check"; fi
case "$out" in *"apps/web: core-js"*) ok "names the workspace and the package" ;; *) bad "did not name them: $out" ;; esac
case "$out" in *"npm install-scripts approve core-js (or deny core-js)"*) ok "prints the command that records a decision" ;; *) bad "no remedy printed: $out" ;; esac

build_sandbox
printf '{"allowScripts":[{"name":"sharp","changes":[]},{"name":"canvas","changes":[]}]}\n' >"$SANDBOX/tree/apps/api/.stub-ls.json"
if out="$(run_check)"; then bad "two unreviewed packages passed"; else ok "two unreviewed packages fail"; fi
case "$out" in *"approve sharp (or deny sharp)"*"approve canvas (or deny canvas)"*) ok "prints a remedy for each package" ;; *) bad "a package got no remedy: $out" ;; esac

echo
echo "check-install-scripts — the ways it could pass having checked nothing all fail closed"

build_sandbox
rm -rf -- "${SANDBOX:?}/tree/apps/api/node_modules"
if out="$(run_check)"; then bad "an uninstalled workspace read as clean"; else ok "a workspace with no installed tree fails"; fi
case "$out" in *"apps/api has no installed tree"*) ok "says which workspace is not installed" ;; *) bad "wrong reason: $out" ;; esac

build_sandbox
if out="$(cd -- "$SANDBOX/tree" && STUB_NPM_VERSION=11.12.1 bash scripts/check-install-scripts.sh 2>&1)"; then
	bad "npm 11.12.1, which ignores allowScripts, passed"
else
	ok "an npm older than 11.20 fails"
fi
case "$out" in *"npm 11.12.1 has no allowScripts support"*) ok "names the npm version it refused" ;; *) bad "wrong reason: $out" ;; esac

build_sandbox
printf 'not json\n' >"$SANDBOX/tree/.stub-ls.json"
if out="$(run_check)"; then bad "unparseable output passed"; else ok "output the parser does not know fails"; fi
case "$out" in *"could not read"*) ok "says the output was unreadable" ;; *) bad "wrong reason: $out" ;; esac

build_sandbox
printf '{"something":"else"}\n' >"$SANDBOX/tree/apps/api/.stub-ls.json"
if out="$(run_check)"; then bad "JSON without allowScripts passed"; else ok "JSON missing the allowScripts list fails"; fi
case "$out" in *"apps/api: could not read"*) ok "says the api output was unreadable" ;; *) bad "wrong reason: $out" ;; esac

build_sandbox
printf '{"allowScripts":{"esbuild":false}}\n' >"$SANDBOX/tree/apps/api/.stub-ls.json"
if out="$(run_check)"; then bad "a non-list allowScripts passed"; else ok "an allowScripts that is not a list fails"; fi
case "$out" in *"apps/api: could not read"*) ok "rejects it as unreadable rather than iterating its keys" ;; *) bad "wrong reason: $out" ;; esac

build_sandbox
printf '{"allowScripts":[{"changes":[]}]}\n' >"$SANDBOX/tree/apps/api/.stub-ls.json"
if out="$(run_check)"; then bad "an entry with no name read as nothing unreviewed"; else ok "an entry with no package name fails"; fi
case "$out" in *"apps/api: could not read"*) ok "rejects the nameless entry as unreadable" ;; *) bad "wrong reason: $out" ;; esac

build_sandbox
printf '{"allowScripts":[{"name":"","changes":[]}]}\n' >"$SANDBOX/tree/apps/api/.stub-ls.json"
if out="$(run_check)"; then bad "an empty package name read as nothing unreviewed"; else ok "an empty package name fails"; fi

build_sandbox
: >"$SANDBOX/tree/apps/api/.stub-ls-fail"
if out="$(run_check)"; then bad "a failing npm command passed"; else ok "a failing npm install-scripts ls fails the check"; fi
case "$out" in *"apps/api: npm install-scripts ls --json failed"*) ok "says the npm command failed" ;; *) bad "wrong reason: $out" ;; esac

build_sandbox
(cd -- "$SANDBOX/tree" && git rm -q --cached -- package-lock.json apps/api/package-lock.json apps/web/package-lock.json)
if out="$(run_check)"; then bad "a tree with no tracked lockfile passed"; else ok "finding no tracked lockfile fails closed"; fi
case "$out" in *"examined nothing"*) ok "says the walk found nothing" ;; *) bad "wrong reason: $out" ;; esac

echo
echo "check-install-scripts — reviewing the package turns it green again"
build_sandbox
printf '{"allowScripts":[{"name":"esbuild","changes":[]}]}\n' >"$SANDBOX/tree/apps/api/.stub-ls.json"
if run_check >/dev/null; then bad "unreviewed esbuild passed"; else ok "unreviewed esbuild fails"; fi
rm -f -- "$SANDBOX/tree/apps/api/.stub-ls.json"
if out="$(run_check)"; then ok "after the decision is recorded, the same tree passes"; else bad "reviewed tree still failed: $out"; fi

echo
echo "=============================================================="
if [ "$fail" -eq 0 ]; then
	echo "install-scripts.test.sh: OK — $pass/$pass assertions passed."
	exit 0
fi
echo "install-scripts.test.sh: FAILED — $fail of $((pass + fail)) assertions failed." >&2
exit 1
