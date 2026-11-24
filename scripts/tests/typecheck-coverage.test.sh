#!/usr/bin/env bash
# Tests that `npm run typecheck` can still fail, and still looks at the files it should.
#
# A compiler upgrade, a tsconfig edit, or a new workspace can make type checking vacuous
# without any check going red: a tsc that rejects nothing, an `include` that no longer reaches
# the code, a scope script reduced to `true`, or a workspace nobody added, all exit 0. The
# SCOPES table below is the one list of what `typecheck` covers, and the guards read it:
#   - every apps/*/tsconfig.json is a scope in the table, so a new workspace fails here until
#     it is wired in;
#   - the root `typecheck` runs each scope's script, and each script is exactly the command
#     in the table (for apps/api, `build:api` runs the workspace build, which must start with
#     `tsc`);
#   - each scope's own tsc rejects a planted type error in a throwaway fixture, and accepts a
#     valid one, so a tsc that fails on everything cannot pass either;
#   - each scope's tsconfig still lists its sentinel files (`tsc -p <dir> --listFilesOnly`).
# Reads the installed tree, as the gauntlet does; a scope without its tsc fails rather than
# being skipped, since a skipped scope is the gap this exists to catch.
#
# bash 3.2-safe: no mapfile, no globstar.

set -u

unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_OBJECT_DIRECTORY \
	GIT_ALTERNATE_OBJECT_DIRECTORIES GIT_COMMON_DIR GIT_NAMESPACE \
	GIT_PREFIX GIT_QUARANTINE_PATH

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"

# scope|root script|its exact command|sentinel files (repo-relative, space-separated)
SCOPES='apps/api|build:api|cd apps/api && npm run build|apps/api/src/index.ts apps/api/src/trpc/routers/llm.test.ts apps/shared/supabase/types.ts
apps/web|typecheck:web|cd apps/web && npx tsc --noEmit|apps/web/app/layout.tsx apps/web/proxy.ts apps/web/lib/trpc.ts apps/web/components/LogoutButton.tsx apps/web/next.config.ts
apps/cron|typecheck:cron|cd apps/cron && npx tsc --noEmit|apps/cron/src/keep-alive.ts
.railway|typecheck:railway|tsc --noEmit -p .railway|.railway/railway.ts'

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
SANDBOX="$(mktemp -d "${TMPDIR:-/tmp}/typecheck-coverage.XXXXXX")"
if [ -z "$SANDBOX" ] || [ ! -d "$SANDBOX" ]; then
	echo "mktemp failed — cannot run tests" >&2
	exit 1
fi
trap 'case "$SANDBOX" in */typecheck-coverage.??????) rm -rf -- "${SANDBOX:?}" ;; esac' EXIT
trap 'case "$SANDBOX" in */typecheck-coverage.??????) rm -rf -- "${SANDBOX:?}" ;; esac; exit 130' INT
trap 'case "$SANDBOX" in */typecheck-coverage.??????) rm -rf -- "${SANDBOX:?}" ;; esac; exit 143' TERM

# The tsc each scope runs: a workspace's own, and the root's for .railway.
tsc_for() {
	case "$1" in
	.railway) printf '%s\n' "$ROOT/node_modules/.bin/tsc" ;;
	*) printf '%s\n' "$ROOT/$1/node_modules/.bin/tsc" ;;
	esac
}

# Prints the value of a package.json script, or nothing.
script_of() {
	(cd -- "$ROOT" && node -e 'const s=require(process.argv[1]).scripts||{};process.stdout.write(s[process.argv[2]]||"")' "$1" "$2")
}

echo "typecheck-coverage — every workspace tsconfig is a scope"
for cfg in "$ROOT"/apps/*/tsconfig.json; do
	[ -f "$cfg" ] || continue
	ws=${cfg#"$ROOT"/}
	ws=${ws%/tsconfig.json}
	if printf '%s\n' "$SCOPES" | cut -d'|' -f1 | grep -qxF -- "$ws"; then ok "$ws is a scope"; else bad "$ws has a tsconfig but is not in SCOPES or the root typecheck"; fi
done

echo
echo "typecheck-coverage — the root typecheck runs each scope's exact command"
root_typecheck=$(script_of ./package.json typecheck)
while IFS='|' read -r scope name command _; do
	[ -n "$scope" ] || continue
	case " $root_typecheck " in
	*" npm run $name "*) ok "typecheck runs $name" ;;
	*) bad "typecheck does not run $name: $root_typecheck" ;;
	esac
	actual=$(script_of ./package.json "$name")
	if [ "$actual" = "$command" ]; then ok "$name is: $command"; else bad "$name is '$actual', expected '$command'"; fi
done <<EOF
$SCOPES
EOF
api_build=$(script_of ./apps/api/package.json build)
case "$api_build" in
"tsc && "* | "tsc") ok "apps/api build starts with tsc: $api_build" ;;
*) bad "apps/api build no longer starts with tsc: $api_build" ;;
esac

echo
echo "typecheck-coverage — each tsc rejects a planted type error"
mkdir -p "$SANDBOX/fixture"
printf '{\n  "compilerOptions": { "strict": true, "noEmit": true, "target": "ES2022", "module": "ESNext", "moduleResolution": "bundler" },\n  "files": ["probe.ts"]\n}\n' >"$SANDBOX/fixture/tsconfig.json"
while IFS='|' read -r scope _ _ _; do
	[ -n "$scope" ] || continue
	tsc=$(tsc_for "$scope")
	if [ ! -x "$tsc" ]; then
		bad "$scope: no tsc at $tsc (install the workspace first)"
		continue
	fi
	printf 'export const probe: number = 1;\n' >"$SANDBOX/fixture/probe.ts"
	if "$tsc" -p "$SANDBOX/fixture" >/dev/null 2>&1 </dev/null; then ok "$scope: tsc accepts a valid file (control)"; else bad "$scope: tsc rejected a valid file"; fi
	printf 'export const probe: number = "not a number";\n' >"$SANDBOX/fixture/probe.ts"
	if out=$("$tsc" -p "$SANDBOX/fixture" 2>&1 </dev/null); then
		bad "$scope: tsc accepted a planted type error"
	else
		case "$out" in *"TS2322"*) ok "$scope: tsc rejects a planted type error with TS2322" ;; *) bad "$scope: tsc failed for another reason: $out" ;; esac
	fi
done <<EOF
$SCOPES
EOF

echo
echo "typecheck-coverage — each tsconfig still covers its sentinel files"
while IFS='|' read -r scope _ _ files; do
	[ -n "$scope" ] || continue
	tsc=$(tsc_for "$scope")
	if [ ! -x "$tsc" ]; then
		bad "$scope: no tsc at $tsc (install the workspace first)"
		continue
	fi
	if ! listed=$(cd -- "$ROOT" && "$tsc" -p "$scope" --listFilesOnly 2>/dev/null </dev/null); then
		bad "$scope: tsc --listFilesOnly failed (does its tsconfig include anything?)"
		continue
	fi
	for f in $files; do
		[ -f "$ROOT/$f" ] || {
			bad "$scope: sentinel $f no longer exists; update SCOPES"
			continue
		}
		if printf '%s\n' "$listed" | grep -qxF -- "$ROOT/$f"; then ok "$scope covers $f"; else bad "$scope no longer covers $f"; fi
	done
done <<EOF
$SCOPES
EOF

echo
echo "=============================================================="
if [ "$fail" -eq 0 ]; then
	echo "typecheck-coverage.test.sh: OK — $pass/$pass assertions passed."
	exit 0
fi
echo "typecheck-coverage.test.sh: FAILED — $fail of $((pass + fail)) assertions failed." >&2
exit 1
