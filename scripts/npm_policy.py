#!/usr/bin/env python3
"""npm_policy.py — the parsing half of check-npm-policy.sh.

Each subcommand reads what it is given, prints one problem per line on stdout, and exits:
  0  clean (some subcommands print a value instead, noted below)
  1  problems found, one per line
  2  input unreadable, which the caller treats as a failure (an input this cannot read must
     never read as "nothing wrong")

Subcommands:
  min-npm <package.json>            print the version in its engines.npm ">=X.Y.Z"
  version-ok <version> <minimum>    exit 0 when version >= minimum
  engines <package.json> <minimum>  engines.npm must be ">=" a version at or above minimum
  config <.npmrc>                   stdin: `npm config ls --json`; the committed file and the
                                    resolved values must both satisfy the policy
  env                               no npm_config_* variable may contradict the policy
  sources <package-lock.json>       every entry comes from the registry with sha512 integrity,
                                    or is bundled inside one that does; prints the count examined
  bootstrap <dir> <minimum>         <dir>/package.json pins npm exactly, its lockfile agrees,
                                    that version is at or above minimum, no entry has an install
                                    script, and <dir>/.npmrc pins the registry and sets nothing
                                    that lets scripts run or changes where packages come from
  parse-ls                          stdin: `npm install-scripts ls --json`; prints one
                                    undecided package name per line

Standard library only.
"""

import json
import os
import re
import sys

REGISTRY = "https://registry.npmjs.org/"
# What every workspace .npmrc must set, and what npm must resolve each to.
REQUIRED = {
    "engine-strict": True,
    "registry": REGISTRY,
    "allow-git": "none",
    "allow-remote": "none",
    "allow-file": "none",
    "allow-directory": "none",
}
# Settings that let an install script run without a decision in package.json allowScripts.
FORBIDDEN = ("allow-scripts", "dangerously-allow-all-scripts")
# Values an inherited npm_config_* variable may hold for each policy key. `npm run` exports
# the root's non-default config this way, and those exports match the policy.
ENV_ALLOWED = {
    **{k: ("true" if v is True else v) for k, v in REQUIRED.items()},
    "dangerously-allow-all-scripts": "false",
    "allow-scripts": "",
}


def norm_key(raw):
    """npm reads `allow-scripts[]`, `allow_scripts` and `ALLOW-SCRIPTS` as the same setting."""
    return raw.strip().lower().replace("_", "-").split("[", 1)[0].strip()


def as_text(value):
    return "true" if value is True else "false" if value is False else str(value)


def parse_version(text):
    m = re.match(r"\s*v?(\d+)\.(\d+)\.(\d+)", text)
    if not m:
        raise ValueError(f"not a version: {text!r}")
    return tuple(int(p) for p in m.groups())


def engines_floor(spec):
    """The X.Y.Z in a plain ">=X.Y.Z" range; anything else (||, ^, a bare version) is None."""
    if not isinstance(spec, str):
        return None
    m = re.fullmatch(r"\s*>=\s*v?(\d+\.\d+\.\d+)\s*", spec)
    return m.group(1) if m else None


def load_json(path):
    with open(path) as fh:
        return json.load(fh)


def cmd_min_npm(path):
    try:
        floor = engines_floor((load_json(path).get("engines") or {}).get("npm"))
    except Exception as exc:
        print(f"{path} could not be read: {exc}")
        return 2
    if not floor:
        print(f'{path} does not declare engines.npm as ">=X.Y.Z"')
        return 1
    print(floor)
    return 0


def cmd_version_ok(version, minimum):
    try:
        return 0 if parse_version(version) >= parse_version(minimum) else 1
    except ValueError:
        return 2


def cmd_engines(path, minimum):
    try:
        floor = engines_floor((load_json(path).get("engines") or {}).get("npm"))
    except Exception as exc:
        print(f"{path} could not be read: {exc}")
        return 2
    if not floor or parse_version(floor) < parse_version(minimum):
        print(f'{path} does not declare engines.npm ">={minimum}" or later')
        return 1
    return 0


def cmd_config(npmrc):
    try:
        resolved = json.load(sys.stdin)
        if not isinstance(resolved, dict):
            raise TypeError("not an object")
    except Exception as exc:
        print(f"npm config ls --json could not be read: {exc}")
        return 2
    try:
        with open(npmrc) as fh:
            lines = fh.read().splitlines()
    except OSError:
        lines = []
    problems = []
    committed = {}
    for raw in lines:
        line = raw.strip()
        if not line or line[0] in "#;":
            continue
        name, _, value = line.partition("=")
        key = norm_key(name)
        if key in FORBIDDEN:
            problems.append(f"{npmrc} sets {name.strip()}, which lets install scripts run without a decision in allowScripts")
        elif key.endswith(":registry") or key == "replace-registry-host":
            problems.append(f"{npmrc} sets {name.strip()}, which changes where packages are fetched from")
        committed[key] = value.strip()
    for key, want in REQUIRED.items():
        text = as_text(want)
        if committed.get(key) != text:
            problems.append(f"{npmrc} does not set {key}={text}")
        elif resolved.get(key) != want:
            problems.append(f"{npmrc} sets {key}={text} but npm resolves it to {resolved.get(key)!r} there; a later setting overrides it")
    if resolved.get("dangerously-allow-all-scripts") is not False:
        problems.append(f"npm resolves dangerously-allow-all-scripts to {resolved.get('dangerously-allow-all-scripts')!r} there, so every install script could run")
    for key, value in resolved.items():
        if key.endswith(":registry"):
            problems.append(f"npm resolves {key} to {value!r} there, which changes where packages are fetched from")
    if resolved.get("replace-registry-host", "npmjs") != "npmjs":
        problems.append(f"npm resolves replace-registry-host to {resolved.get('replace-registry-host')!r} there, which changes where packages are fetched from")
    allow = resolved.get("allow-scripts")
    if allow not in ([""], [], "", None):
        problems.append(f"npm resolves allow-scripts to {allow!r} there; decide install scripts in package.json allowScripts only")
    for line in problems:
        print(line)
    return 1 if problems else 0


def cmd_env():
    problems = []
    for name, value in sorted(os.environ.items()):
        if not name.lower().startswith("npm_config_"):
            continue
        key = norm_key(name[len("npm_config_"):])
        if key.endswith(":registry") or key == "replace-registry-host":
            problems.append(f"environment variable {name} changes where packages are fetched from")
        elif key in ENV_ALLOWED and value.strip().lower() != ENV_ALLOWED[key].lower():
            problems.append(f"environment variable {name}={value!r} overrides the npm policy ({key} must be {ENV_ALLOWED[key]!r})")
    for line in problems:
        print(line)
    return 1 if problems else 0


def cmd_sources(lockfile):
    try:
        data = load_json(lockfile)
    except Exception as exc:
        print(f"{lockfile} could not be read: {exc}")
        return 2
    version = data.get("lockfileVersion") if isinstance(data, dict) else None
    if not isinstance(version, int) or version < 2:
        print(f"{lockfile} is not lockfileVersion 2 or later, so where its packages come from cannot be checked")
        return 1
    packages = data.get("packages")
    if not isinstance(packages, dict) or "" not in packages:
        print(f"{lockfile} has no packages map with a root entry, so where its packages come from cannot be checked")
        return 1
    bad = []
    examined = 0
    for key, entry in packages.items():
        if not key:
            continue
        examined += 1
        if not isinstance(entry, dict):
            bad.append(f"{key} (unreadable entry)")
            continue
        resolved = entry.get("resolved")
        if resolved is not None and not isinstance(resolved, str):
            bad.append(f"{key} (resolved is not a string)")
            continue
        if resolved is None:
            if not entry.get("inBundle"):
                bad.append(f"{key} (no registry source)")
                continue
            # Bundled entries ship inside an ancestor's tarball: walk up to the first ancestor
            # that is not itself bundled, and require that one to come from the registry.
            parent = key
            while True:
                if "/node_modules/" not in parent:
                    parent = None
                    break
                parent = parent.rsplit("/node_modules/", 1)[0]
                p = packages.get(parent)
                if not (isinstance(p, dict) and p.get("inBundle")):
                    break
            p = packages.get(parent) if parent else None
            if not (isinstance(p, dict) and str(p.get("resolved", "")).startswith(REGISTRY)):
                bad.append(f"{key} (bundled in {parent or 'nothing'}, which is not from the registry)")
        elif not resolved.startswith(REGISTRY):
            bad.append(f"{key} ({resolved})")
        elif not str(entry.get("integrity", "")).startswith("sha512-"):
            bad.append(f"{key} (no sha512 integrity)")
    if bad:
        more = f" and {len(bad) - 5} more" if len(bad) > 5 else ""
        print(f"{lockfile} installs from outside the npm registry or without integrity: " + "; ".join(bad[:5]) + more)
        return 1
    print(examined)
    return 0


def cmd_bootstrap(directory, minimum):
    manifest = os.path.join(directory, "package.json")
    lockfile = os.path.join(directory, "package-lock.json")
    try:
        pinned = (load_json(manifest).get("dependencies") or {}).get("npm")
        locked = (load_json(lockfile).get("packages") or {}).get("node_modules/npm", {}).get("version")
    except Exception as exc:
        print(f"{directory} could not be read: {exc}")
        return 2
    if not isinstance(pinned, str) or not re.fullmatch(r"\d+\.\d+\.\d+", pinned):
        print(f"{manifest} must pin npm to an exact version")
        return 1
    if locked != pinned:
        print(f"{lockfile} locks npm {locked!r}, but {manifest} pins {pinned}; run npm install there")
        return 1
    if parse_version(pinned) < parse_version(minimum):
        print(f"{manifest} pins npm {pinned}, below the {minimum} that engines.npm requires")
        return 1
    scripted = [k for k, v in (load_json(lockfile).get("packages") or {}).items() if isinstance(v, dict) and v.get("hasInstallScript")]
    if scripted:
        print(f"{lockfile} has entries with install scripts ({', '.join(scripted[:3])}); the bootstrap is installed by an npm that would run them undecided")
        return 1
    npmrc = os.path.join(directory, ".npmrc")
    problems = []
    try:
        with open(npmrc) as fh:
            lines = fh.read().splitlines()
    except OSError:
        lines = []
    committed = {}
    for raw in lines:
        line = raw.strip()
        if not line or line[0] in "#;":
            continue
        name, _, value = line.partition("=")
        key = norm_key(name)
        if key in FORBIDDEN:
            problems.append(f"{npmrc} sets {name.strip()}, which lets install scripts run without a decision")
        elif key.endswith(":registry") or key == "replace-registry-host":
            problems.append(f"{npmrc} sets {name.strip()}, which changes where packages are fetched from")
        committed[key] = value.strip()
    if committed.get("registry") != REGISTRY:
        problems.append(f"{npmrc} does not set registry={REGISTRY}")
    if problems:
        for line in problems:
            print(line)
        return 1
    print(pinned)
    return 0


def cmd_parse_ls():
    try:
        entries = json.load(sys.stdin)["allowScripts"]
        if not isinstance(entries, list):
            raise TypeError("allowScripts is not a list")
        names = []
        for entry in entries:
            name = entry["name"]
            if not isinstance(name, str) or not name:
                raise ValueError("an entry has no package name")
            names.append(name)
    except Exception as exc:
        print(f"unrecognized output: {exc}", file=sys.stderr)
        return 2
    for name in names:
        print(name)
    return 0


def main(argv):
    commands = {
        "min-npm": (cmd_min_npm, 1),
        "version-ok": (cmd_version_ok, 2),
        "engines": (cmd_engines, 2),
        "config": (cmd_config, 1),
        "env": (cmd_env, 0),
        "sources": (cmd_sources, 1),
        "bootstrap": (cmd_bootstrap, 2),
        "parse-ls": (cmd_parse_ls, 0),
    }
    if len(argv) < 2 or argv[1] not in commands or len(argv) - 2 != commands[argv[1]][1]:
        print(f"usage: npm_policy.py {{{'|'.join(commands)}}} ...", file=sys.stderr)
        return 2
    func, _ = commands[argv[1]]
    return func(*argv[2:])


if __name__ == "__main__":
    sys.exit(main(sys.argv))
