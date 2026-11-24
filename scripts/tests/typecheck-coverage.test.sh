#!/usr/bin/env bash
# Tests that `npm run typecheck` can still fail, and still looks at the files it should.
#
# A compiler upgrade, a tsconfig edit, or a new workspace can make type checking vacuous
# without any check going red: a tsc that rejects nothing, or an `include` that no longer
# reaches the code, both exit 0. Two guards:
#   - Each workspace's own tsc rejects a planted type error in a throwaway fixture (and
#     accepts a valid one, so a tsc that fails on everything cannot pass this either).
#   - Each tsconfig the root `typecheck` runs still lists named sentinel files, read from
#     `tsc -p <dir> --listFilesOnly`, so a narrowed `include` fails here instead of silently
#     checking less.
# Both read the installed tree; the gauntlet runs on one. A workspace without its tsc fails
# rather than being skipped, since a skipped scope is exactly the gap this exists to catch.
#
# bash 3.2-safe: no mapfile, no globstar.

set -u

unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_OBJECT_DIRECTORY \
	GIT_ALTERNATE_OBJECT_DIRECTORIES GIT_COMMON_DIR GIT_NAMESPACE \
	GIT_PREFIX GIT_QUARANTINE_PATH

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"

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

SANDBOX="$(mktemp -d -t typecheck-coverage.XXXXXX)"
if [ -z "$SANDBOX" ] || [ ! -d "$SANDBOX" ]; then
	echo "mktemp failed — cannot run tests" >&2
	exit 1
fi
trap 'case "$SANDBOX" in */typecheck-coverage.??????) rm -rf -- "${SANDBOX:?}" ;; esac' EXIT
trap 'case "$SANDBOX" in */typecheck-coverage.??????) rm -rf -- "${SANDBOX:?}" ;; esac; exit 130' INT
trap 'case "$SANDBOX" in */typecheck-coverage.??????) rm -rf -- "${SANDBOX:?}" ;; esac; exit 143' TERM

# The tsc each scope of the root `typecheck` runs: a workspace's own, and the root's for .railway.
tsc_for() {
	case "$1" in
	.railway) printf '%s\n' "$ROOT/node_modules/.bin/tsc" ;;
	*) printf '%s\n' "$ROOT/$1/node_modules/.bin/tsc" ;;
	esac
}

echo "typecheck-coverage — each tsc rejects a planted type error"
mkdir -p "$SANDBOX/fixture"
printf '{\n  "compilerOptions": { "strict": true, "noEmit": true, "target": "ES2022", "module": "ESNext", "moduleResolution": "bundler" },\n  "files": ["probe.ts"]\n}\n' >"$SANDBOX/fixture/tsconfig.json"
for scope in apps/api apps/web apps/cron .railway; do
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
done

echo
echo "typecheck-coverage — each tsconfig still covers its sentinel files"
# scope|sentinel paths relative to the repo root, space-separated
SENTINELS='apps/api|apps/api/src/index.ts apps/api/src/trpc/routers/llm.test.ts apps/shared/supabase/types.ts
apps/web|apps/web/app/layout.tsx apps/web/proxy.ts apps/web/lib/trpc.ts apps/web/components/LogoutButton.tsx apps/web/next.config.ts
apps/cron|apps/cron/src/keep-alive.ts
.railway|.railway/railway.ts'
while IFS='|' read -r scope files; do
	[ -n "$scope" ] || continue
	tsc=$(tsc_for "$scope")
	if [ ! -x "$tsc" ]; then
		bad "$scope: no tsc at $tsc (install the workspace first)"
		continue
	fi
	if ! listed=$(cd -- "$ROOT" && "$tsc" -p "$scope" --listFilesOnly 2>/dev/null </dev/null); then
		bad "$scope: tsc --listFilesOnly failed"
		continue
	fi
	for f in $files; do
		[ -f "$ROOT/$f" ] || {
			bad "$scope: sentinel $f no longer exists; update this test"
			continue
		}
		if printf '%s\n' "$listed" | grep -qxF -- "$ROOT/$f"; then ok "$scope covers $f"; else bad "$scope no longer covers $f"; fi
	done
done <<EOF
$SENTINELS
EOF

echo
echo "typecheck-coverage — the root typecheck script runs every scope"
script=$(cd -- "$ROOT" && node -e 'process.stdout.write(require("./package.json").scripts.typecheck)')
for part in "build:api" "typecheck:web" "typecheck:cron" "typecheck:railway"; do
	case " $script " in *"npm run $part "* | *"npm run $part") ok "typecheck runs $part" ;; *) bad "typecheck does not run $part: $script" ;; esac
done

echo
echo "=============================================================="
if [ "$fail" -eq 0 ]; then
	echo "typecheck-coverage.test.sh: OK — $pass/$pass assertions passed."
	exit 0
fi
echo "typecheck-coverage.test.sh: FAILED — $fail of $((pass + fail)) assertions failed." >&2
exit 1
