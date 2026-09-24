#!/usr/bin/env bash
# Tests for scripts/check-node-version-ssot.sh — the check that keeps one Node major
# stated in `.nvmrc` and enforced across every other declaration in the tree.
#
# Every case runs against a SANDBOX tree, never the real repo: the whole point is to
# introduce drift and watch the check go red, and doing that in place would edit the
# repo's own manifests. The sandbox holds the same shapes the real tree has — a root
# manifest, app manifests, and Dockerfiles — because the check walks them by find.
#
# The control case matters as much as the failures: a check that cannot pass is as
# useless as one that cannot fail, and a bad sandbox path would make every "it failed"
# assertion pass for the wrong reason.
#
# bash 3.2-safe: no mapfile, no globstar.

set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT="$ROOT/scripts/check-node-version-ssot.sh"

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

SANDBOX="$(mktemp -d)"
if [ -z "$SANDBOX" ] || [ ! -d "$SANDBOX" ]; then
	echo "mktemp failed — cannot run tests" >&2
	exit 1
fi
# Guarded per the destructive-deletion rules: non-empty, and inside the temp dir this
# test created. Kept inline in each trap rather than a named function — a function reached
# only through `trap` looks uninvoked to shellcheck. EXIT covers normal and failing runs;
# INT and TERM clean up and then exit, because a signal handler that does not exit lets
# the script resume and keep running after Ctrl-C.
trap 'case "$SANDBOX" in /tmp/* | /var/folders/*) rm -rf "${SANDBOX:?}" ;; esac' EXIT
trap 'case "$SANDBOX" in /tmp/* | /var/folders/*) rm -rf "${SANDBOX:?}" ;; esac; exit 130' INT
trap 'case "$SANDBOX" in /tmp/* | /var/folders/*) rm -rf "${SANDBOX:?}" ;; esac; exit 143' TERM

# Build a tree that agrees with itself on Node 22.
build_sandbox() {
	rm -rf "${SANDBOX:?}/tree"
	mkdir -p "$SANDBOX/tree/scripts" "$SANDBOX/tree/apps/api" "$SANDBOX/tree/apps/web"
	cp "$SCRIPT" "$SANDBOX/tree/scripts/check-node-version-ssot.sh"
	printf '22\n' >"$SANDBOX/tree/.nvmrc"
	printf '{\n  "name": "root",\n  "engines": { "node": ">=22.0.0" }\n}\n' >"$SANDBOX/tree/package.json"
	printf '{\n  "name": "api",\n  "engines": { "node": ">=22.0.0" }\n}\n' >"$SANDBOX/tree/apps/api/package.json"
	printf '{\n  "name": "web",\n  "engines": { "node": ">=22.0.0" }\n}\n' >"$SANDBOX/tree/apps/web/package.json"
	printf 'FROM node:22-alpine\n' >"$SANDBOX/tree/apps/api/Dockerfile"
	printf 'FROM node:22-bookworm-slim\n' >"$SANDBOX/tree/apps/web/Dockerfile"
}

run_check() { bash "$SANDBOX/tree/scripts/check-node-version-ssot.sh" 2>&1; }

echo "check-node-version-ssot — an aligned tree passes (control)"
build_sandbox
if out="$(run_check)"; then ok "exits 0 when every declaration agrees"; else bad "aligned tree failed: $out"; fi
case "$out" in *"agrees with .nvmrc (22)"*) ok "names the major it enforced" ;; *) bad "no confirmation line: $out" ;; esac

echo
echo "check-node-version-ssot — each kind of drift is caught"

build_sandbox
printf '{\n  "name": "web",\n  "engines": { "node": ">=24.0.0" }\n}\n' >"$SANDBOX/tree/apps/web/package.json"
if out="$(run_check)"; then bad "drifted engines.node passed"; else ok "a package.json on a different major fails"; fi
case "$out" in *"apps/web/package.json"*) ok "names the offending manifest" ;; *) bad "did not name the file: $out" ;; esac

build_sandbox
printf 'FROM node:24-alpine\n' >"$SANDBOX/tree/apps/api/Dockerfile"
if out="$(run_check)"; then bad "drifted Dockerfile passed"; else ok "a Dockerfile on a different major fails"; fi
case "$out" in *"node:24-alpine"*) ok "names the offending tag" ;; *) bad "did not name the tag: $out" ;; esac

build_sandbox
printf '{\n  "name": "web"\n}\n' >"$SANDBOX/tree/apps/web/package.json"
if out="$(run_check)"; then bad "missing engines.node passed"; else ok "a manifest declaring NO engines.node fails"; fi

build_sandbox
printf '{ this is not json\n' >"$SANDBOX/tree/apps/web/package.json"
if out="$(run_check)"; then bad "a malformed package.json passed"; else ok "a malformed package.json fails"; fi
case "$out" in *"apps/web/package.json is not valid JSON"*) ok "names the malformed manifest, not a missing field" ;; *) bad "wrong reason: $out" ;; esac

build_sandbox
rm -f "$SANDBOX/tree/.nvmrc"
if out="$(run_check)"; then bad "missing .nvmrc passed"; else ok "a missing .nvmrc fails rather than defaulting"; fi

build_sandbox
printf 'lts/hydrogen\n' >"$SANDBOX/tree/.nvmrc"
if out="$(run_check)"; then bad "junk .nvmrc passed"; else ok "a non-numeric .nvmrc fails rather than comparing against junk"; fi

echo
echo "check-node-version-ssot — a broken walk fails rather than reporting a clean tree"
build_sandbox
# The manifest loop is fed by process substitution, which `pipefail` cannot reach into: if
# the reader dies, the loop sees no input, finds no disagreement, and would report OK having
# checked nothing. Break the reader and confirm it refuses instead.
sed "s/node -e '/node --nonexistent-flag -e '/" "$SCRIPT" >"$SANDBOX/tree/scripts/check-node-version-ssot.sh"
if out="$(run_check)"; then bad "a broken reader reported success"; else ok "a reader that dies fails the check"; fi
case "$out" in *"examined no package.json"*) ok "says the check is broken, not that the tree is clean" ;; *) bad "wrong failure reason: $out" ;; esac

echo
echo "check-node-version-ssot — the FROM parsing accepts every ordinary Dockerfile form"
# Each case below would defeat a naive `^FROM +node:` grep plus `cut -d-`: either
# skipped entirely (reporting OK having examined nothing) or failed on a correct file.
# Dashed real-world tags would hide it — `cut -d-` truncates the stage name as a side
# effect, so the bug would only surface on a bare `node:22`.

build_sandbox
printf 'FROM node:22 AS builder\n' >"$SANDBOX/tree/apps/api/Dockerfile"
if out="$(run_check)"; then ok "a bare tag with a stage name passes (was a false failure)"; else bad "multi-stage bare tag failed: $out"; fi

build_sandbox
# `\$` in double quotes rather than a single-quoted `$`: the dollar is literal Dockerfile
# text, and writing it this way says so instead of leaving shellcheck to guess (SC2016).
printf "FROM --platform=\$BUILDPLATFORM node:24-alpine\n" >"$SANDBOX/tree/apps/api/Dockerfile"
if out="$(run_check)"; then bad "a --platform line was skipped, so drift passed"; else ok "drift behind a --platform flag is caught (was skipped)"; fi

build_sandbox
printf 'from node:24-alpine\n' >"$SANDBOX/tree/apps/api/Dockerfile"
if out="$(run_check)"; then bad "a lowercase FROM was skipped, so drift passed"; else ok "drift on a lowercase 'from' is caught (was skipped)"; fi

build_sandbox
printf 'FROM docker.io/library/node:24 AS builder\n' >"$SANDBOX/tree/apps/api/Dockerfile"
if out="$(run_check)"; then bad "a registry-qualified image was skipped, so drift passed"; else ok "drift on a registry-qualified image is caught"; fi

build_sandbox
printf '\tFROM\tnode:24-alpine\n' >"$SANDBOX/tree/apps/api/Dockerfile"
if out="$(run_check)"; then bad "a tab-indented FROM was skipped, so drift passed"; else ok "drift on a tab-indented FROM is caught"; fi

build_sandbox
printf '# FROM node:24-alpine\nFROM node:22-alpine\n' >"$SANDBOX/tree/apps/api/Dockerfile"
if out="$(run_check)"; then ok "a commented-out FROM is not read as a pin"; else bad "comment line was treated as a pin: $out"; fi

echo
echo "check-node-version-ssot — an unreadable pin is named, not skipped"
build_sandbox
printf 'FROM node AS builder\n' >"$SANDBOX/tree/apps/api/Dockerfile"
if out="$(run_check)"; then bad "an untagged node image passed"; else ok "an untagged 'FROM node' fails rather than being ignored"; fi
case "$out" in *"no tag"*) ok "says the pin declares no major" ;; *) bad "wrong reason: $out" ;; esac

build_sandbox
printf 'FROM node:lts-alpine\n' >"$SANDBOX/tree/apps/api/Dockerfile"
if out="$(run_check)"; then bad "a non-numeric tag passed"; else ok "a tag with no numeric major (node:lts-alpine) fails"; fi
case "$out" in *"whose Node major cannot be read"*) ok "says the major cannot be read" ;; *) bad "wrong reason: $out" ;; esac

build_sandbox
printf 'FROM node@sha256:0000000000000000000000000000000000000000000000000000000000000000\n' >"$SANDBOX/tree/apps/api/Dockerfile"
if out="$(run_check)"; then bad "a digest-pinned node image passed"; else ok "a digest pin fails rather than being ignored"; fi

echo
echo "check-node-version-ssot — a Dockerfile walk that finds nothing fails closed"
# The mirror of the manifest guard. Both loops are fed by process substitution, so neither
# can fail the script the way a pipeline would; without a count, a parse that matches
# nothing reports a clean tree having examined nothing at all.
build_sandbox
printf 'FROM redis:7-alpine\n' >"$SANDBOX/tree/apps/api/Dockerfile"
printf 'FROM postgres:17-alpine\n' >"$SANDBOX/tree/apps/web/Dockerfile"
if out="$(run_check)"; then bad "no Node pin anywhere reported a clean tree"; else ok "Dockerfiles with no Node pin fail closed"; fi
case "$out" in *"FROM parsing failed"*) ok "says the parsing broke, not that the tree is clean" ;; *) bad "wrong reason: $out" ;; esac

build_sandbox
rm -f "$SANDBOX/tree/apps/api/Dockerfile" "$SANDBOX/tree/apps/web/Dockerfile"
if out="$(run_check)"; then bad "a tree with no Dockerfile at all reported success"; else ok "finding no Dockerfile at all fails closed"; fi
case "$out" in *"examined no Dockerfile"*) ok "says the walk failed" ;; *) bad "wrong reason: $out" ;; esac

echo
echo "check-node-version-ssot — the .nvmrc is genuinely the source of truth"
build_sandbox
printf '24\n' >"$SANDBOX/tree/.nvmrc"
if out="$(run_check)"; then bad "bumping .nvmrc alone passed"; else ok "moving .nvmrc alone reddens everything else"; fi
# Bump the whole tree together and it goes green again — which is what "one place to
# change" has to mean in practice.
printf '{\n  "name": "root",\n  "engines": { "node": ">=24.0.0" }\n}\n' >"$SANDBOX/tree/package.json"
printf '{\n  "name": "api",\n  "engines": { "node": ">=24.0.0" }\n}\n' >"$SANDBOX/tree/apps/api/package.json"
printf '{\n  "name": "web",\n  "engines": { "node": ">=24.0.0" }\n}\n' >"$SANDBOX/tree/apps/web/package.json"
printf 'FROM node:24-alpine\n' >"$SANDBOX/tree/apps/api/Dockerfile"
printf 'FROM node:24-bookworm-slim\n' >"$SANDBOX/tree/apps/web/Dockerfile"
if out="$(run_check)"; then ok "a whole-tree bump to 24 passes"; else bad "aligned bump failed: $out"; fi

echo
echo "=============================================================="
if [ "$fail" -eq 0 ]; then
	echo "node-version-ssot.test.sh: OK — $pass/$pass assertions passed."
	exit 0
fi
echo "node-version-ssot.test.sh: FAILED — $fail of $((pass + fail)) assertions failed." >&2
exit 1
