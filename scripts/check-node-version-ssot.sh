#!/usr/bin/env bash
#
# check-node-version-ssot.sh — one Node major, declared in one place, enforced everywhere.
#
# `.nvmrc` holds the major and is the source of truth. Every other declaration must agree:
# `engines.node` in every package.json we ship, and every `FROM node:` tag in every
# Dockerfile. Both populations are found by walking the tree, so an app added later is
# covered without touching this script. Deliberately no count is written down here — a
# hard-coded one is wrong the moment someone adds an app. To see the current set:
#   find . -name package.json -not -path '*/node_modules/*' -not -path '*/.next/*'
#   find . -name Dockerfile -not -path '*/node_modules/*'
#
# The failure this exists for: a dependency bot moves `.nvmrc` and the Dockerfiles and
# leaves `engines` behind, so nothing refuses to run until something meets the wrong
# runtime in production.
#
# Exits non-zero listing every declaration that disagrees. Read-only; changes nothing.
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
nvmrc="$root/.nvmrc"

[ -f "$nvmrc" ] || {
	echo "check-node-version-ssot: FAIL — $nvmrc is missing; it is the source of truth." >&2
	exit 1
}

# Accept "22" or "22.1.0"; the major is what every other declaration must agree with.
expected=$(tr -d '[:space:]' <"$nvmrc" | sed 's/^v//' | cut -d. -f1)
case "$expected" in
'' | *[!0-9]*)
	echo "check-node-version-ssot: FAIL — .nvmrc must hold a Node major (e.g. 22); got '$(cat "$nvmrc")'." >&2
	exit 1
	;;
esac

problems=0
manifests_seen=0
note() {
	echo "  ✗ $1" >&2
	problems=$((problems + 1))
}

# Directories that can hold a package.json or Dockerfile we do not ship. An array rather
# than a string, so every word stays quoted at the call site: a plain string would have to
# be left unquoted to word-split, which needs a lint suppression an array does not.
PRUNE=('(' -name node_modules -o -name .next -o -name .git -o -name dist ')' -prune)

# --- engines.node in every package.json we ship -------------------------------------------
# Every manifest must state one, or a package silently accepts any Node at all.
#
# One node process reads them all. Spawning node per manifest cost ~3s, and this check runs
# in the gauntlet — a cost paid on every commit, in every lane, forever.
while IFS="$(printf '\t')" read -r manifest declared; do
	[ -n "$manifest" ] || continue
	manifests_seen=$((manifests_seen + 1))
	rel=${manifest#"$root"/}
	if [ "$declared" = "!parse-error" ]; then
		note "$rel is not valid JSON, so its engines.node cannot be read"
		continue
	fi
	if [ -z "$declared" ]; then
		note "$rel declares no engines.node (expected >=${expected}.0.0)"
		continue
	fi
	# Compare the major only — the range operator is a policy choice, the major is the fact.
	declared_major=$(printf '%s' "$declared" | grep -oE '[0-9]+' | head -1)
	[ "$declared_major" = "$expected" ] ||
		note "$rel says engines.node '$declared' but .nvmrc says $expected"
done < <(
	find "$root" "${PRUNE[@]}" -o -name package.json -print |
		sort |
		node -e '
      const fs = require("fs");
      let input = "";
      process.stdin.on("data", (d) => (input += d));
      process.stdin.on("end", () => {
        for (const file of input.split("\n").filter(Boolean)) {
          let declared;
          try {
            const pkg = JSON.parse(fs.readFileSync(file, "utf8"));
            declared = (pkg.engines && pkg.engines.node) || "";
          } catch {
            // A malformed manifest is a real problem; say so rather than reading it as
            // "declares nothing", which would name the wrong defect.
            declared = "!parse-error";
          }
          process.stdout.write(file + "\t" + declared + "\n");
        }
      });
    '
)

# A reader feeding this loop through process substitution cannot fail the script the way a
# pipeline can — `pipefail` does not reach into `< <(...)`. So if the walk or the node
# process dies, the loop reads nothing, finds no disagreement, and reports OK having
# examined nothing at all. The root manifest always exists, so zero is never a real answer.
if [ "$manifests_seen" -eq 0 ]; then
	echo "check-node-version-ssot: FAIL — examined no package.json at all; the walk or its" >&2
	echo "reader failed. This is a broken check, not a clean tree." >&2
	exit 1
fi

# --- FROM node:<major> in every Dockerfile -------------------------------------------------
# Permissive about the FORM, strict about the RESULT — because every form this fails to
# match is a silent skip rather than a failure. A Dockerfile may lowercase `from`, put
# BuildKit flags before the image (`--platform=$BUILDPLATFORM`), qualify the registry
# (`docker.io/library/node:22`), and name a stage after it (`AS builder`). All are
# ordinary, none changes the pin, and the earlier `^FROM +node:` grep saw none of them.
#
# awk splits on whitespace, so indentation and tabs cost nothing: $1 is the instruction,
# leading `--flag` tokens are skipped, and the next token is the image. Stopping there is
# what drops the stage name — the previous version relied on `cut -d-` truncating it as a
# side effect, which worked only because every real tag happened to contain a dash.
dockerfiles_seen=0
node_pins_seen=0
while IFS= read -r dockerfile; do
	dockerfiles_seen=$((dockerfiles_seen + 1))
	rel=${dockerfile#"$root"/}
	while IFS= read -r image; do
		# Strip any registry/namespace prefix, so `docker.io/library/node:22` is recognized
		# while `mynode:22` still is not.
		ref=${image##*/}
		case "$ref" in
		node | node:* | node@*) ;;
		*) continue ;; # a non-node base image is not this check's business
		esac
		node_pins_seen=$((node_pins_seen + 1))
		case "$ref" in
		node)
			note "$rel pins '$image' with no tag, so it declares no Node major"
			continue
			;;
		node@*)
			note "$rel pins '$image' by digest, so it declares no Node major"
			continue
			;;
		esac
		tag=${ref#node:}
		tag_major=${tag%%-*}
		tag_major=${tag_major%%.*}
		case "$tag_major" in
		'' | *[!0-9]*)
			note "$rel pins '$image', whose Node major cannot be read"
			continue
			;;
		esac
		[ "$tag_major" = "$expected" ] ||
			note "$rel pins '$image' but .nvmrc says $expected"
	done < <(awk '
      tolower($1) != "from" { next }
      {
        i = 2
        while (i <= NF && substr($i, 1, 2) == "--") i++
        if (i <= NF) print $i
      }
    ' "$dockerfile")
done < <(find "$root" "${PRUNE[@]}" -o -name Dockerfile -print | sort)

# The same fail-open shape the manifest walk guards against, for the same reason: a reader
# fed by process substitution cannot fail the script, so a broken walk or a parse that
# matches nothing reports a clean tree having examined nothing. Two counts because they
# break differently — zero Dockerfiles means the walk died, and zero node pins across all
# of them means the FROM parsing did. If this repo ever legitimately ships no Node image,
# the second guard is the line to revisit; until then a zero there is a broken check.
if [ "$dockerfiles_seen" -eq 0 ]; then
	echo "check-node-version-ssot: FAIL — examined no Dockerfile at all; the walk failed." >&2
	echo "This is a broken check, not a clean tree." >&2
	exit 1
fi
if [ "$node_pins_seen" -eq 0 ]; then
	echo "check-node-version-ssot: FAIL — found $dockerfiles_seen Dockerfile(s) but no Node" >&2
	echo "image pinned in any of them; the FROM parsing failed, so nothing was checked." >&2
	exit 1
fi

if [ "$problems" -gt 0 ]; then
	echo "check-node-version-ssot: FAIL — $problems declaration(s) disagree with .nvmrc ($expected)." >&2
	echo "Update them together, or change .nvmrc and re-run. A dependency bot moves the" >&2
	echo ".nvmrc and Dockerfiles only, so this check is what catches the half it leaves behind." >&2
	exit 1
fi

echo "check-node-version-ssot: OK — every Node declaration agrees with .nvmrc ($expected)."
