#!/usr/bin/env python3
"""npm_policy_deploy.py — the deploy-file half of check-npm-policy.sh, as a closed allowlist.

The rule (CLAUDE.md, "npm 12 is required"): deploys install dependencies only with the npm
bootstrapped from tools/npm, never fetch npm itself, and never change npm's configuration. A
shell has more ways to spell a program than any deny-list can name (globs, decoders piped into
a shell, interpreters, wrappers), so every command a deploy file runs must be one of the
ALLOWED_SHAPES, whether or not it mentions npm. Anything else fails, and the fix is to add the
new shape here, where it is reviewed.

Read: each RUN, CMD, ENTRYPOINT, HEALTHCHECK CMD and ONBUILD in any Dockerfile or Containerfile;
installCommand, buildCommand, devCommand and ignoreCommand in vercel.json (installCommand is
required); `start` in .railway/railway.ts and the Dockerfile its dockerfilePath names. A command
is `&&`-joined simple commands, grouped at most by parentheses. Also refused: $, backticks,
heredocs and newlines in a command; SHELL; an escape parser directive; COPY or ADD naming an
npmrc; ADD from a URL; ENV or ARG setting npm_config_*, NPM_*, PATH, HOME, XDG_CONFIG_HOME,
NODE_OPTIONS or NODE_PATH; npm configuration in vercel.json env; a railway.ts that mentions a
package manager, sets another command key or builder, or sets start or dockerfilePath to
anything but a plain string (start may also be encodeFunctionScript('<path>')).

Not covered: what a program allowed here does when it runs code the repo commits — the body of
an `npm run <script>` in package.json, the script `node <script>` runs, and a base image's own
contents. Those are reviewed as code.

Standard library only. Usage: `git ls-files -z | python3 -I npm_policy_deploy.py`; exits 0 when
clean, 1 with one problem per line, never 0 when no deploy file was found.
"""

import json
import os
import re
import shlex
import sys

BOOTSTRAP_DIR = "tools/npm"
BOOTSTRAP_BIN = BOOTSTRAP_DIR + "/node_modules/.bin/npm"
CI_FLAGS = {"--no-audit", "--no-fund"}
NODE_FLAGS = {"--expose-gc", "--enable-source-maps"}
SCRIPT_NAME = re.compile(r"[A-Za-z0-9][A-Za-z0-9:._-]*")
SCRIPT_PATH = re.compile(r"[A-Za-z0-9_./-]+\.(?:js|mjs|cjs)")
ALLOWED_SHAPES = (
    "`cd <dir>`, `npm ci` right after `cd <root>/tools/npm`, `<root>/tools/npm/node_modules/.bin/npm ci` "
    "or `... run <script>`, `npm run <script>`, `npx tsc`, `node [--expose-gc] <file>.js`"
)
# Package-manager names as whole words; a hyphenated name such as an image `function-bun` is not one.
SENSITIVE = re.compile(r"(?<![\w-])(npm|npx|pnpm|yarn|bun|corepack)(?![\w-])|npmrc", re.IGNORECASE)
DYNAMIC = re.compile(r"[$`\n\r]|<<")
# Variables that change which programs run or which config npm reads.
LOADER_VARS = re.compile(r"(?i)^(npm_config_\w*|npm_\w*|path|home|xdg_config_home|node_options|node_path)$")
COMMAND_INSTRUCTIONS = {"RUN", "CMD", "ENTRYPOINT"}
VERCEL_COMMANDS = ("installCommand", "buildCommand", "devCommand", "ignoreCommand")
JS_STRING = r"'(?:[^'\\\n]|\\.)*'|\"(?:[^\"\\\n]|\\.)*\""


def is_root_path(word, roots, suffix):
    """True when word is <root>/<suffix> for an allowed root: any run of ../ (vercel.json
    commands run inside an app directory) or a Dockerfile's first WORKDIR."""
    path = word.rstrip("/")
    if re.fullmatch(r"(?:\.\./)*" + re.escape(suffix), path):
        return True
    return any(path == f"{root}/{suffix}" for root in roots)


def find_part_problem(words, in_bootstrap_dir, roots):
    """None when one simple command is an allowed shape, else why it is not."""
    prog, args = words[0], words[1:]
    allowed = False
    if prog == "cd":
        allowed = len(args) == 1 and not args[0].startswith("-")
    elif prog == "npm":
        allowed = (in_bootstrap_dir and args[:1] == ["ci"] and set(args[1:]) <= CI_FLAGS) or (
            len(args) == 2 and args[0] == "run" and SCRIPT_NAME.fullmatch(args[1]) is not None
        )
    elif is_root_path(prog, roots, BOOTSTRAP_BIN):
        allowed = (args[:1] == ["ci"] and set(args[1:]) <= CI_FLAGS) or (
            len(args) == 2 and args[0] == "run" and SCRIPT_NAME.fullmatch(args[1]) is not None
        )
    elif prog == "npx":
        allowed = args == ["tsc"]
    elif prog == "node":
        flags = [a for a in args if a.startswith("-")]
        files = [a for a in args if not a.startswith("-")]
        allowed = set(flags) <= NODE_FLAGS and len(files) == 1 and args[-1] == files[0] and SCRIPT_PATH.fullmatch(files[0]) is not None
    if allowed:
        return None
    return f"runs `{' '.join(words)}`, which is not an allowed deploy command (allowed: {ALLOWED_SHAPES}; add a new shape to scripts/npm_policy_deploy.py)"


def check_words(tokens, where, roots):
    """Judge a tokenized command (shell tokens, or an exec-form word list)."""
    problems = []
    part, in_bootstrap_dir = [], False

    def close_part():
        nonlocal in_bootstrap_dir
        if not part:
            return
        problem = find_part_problem(part, in_bootstrap_dir, roots)
        if problem:
            problems.append(f"{where} {problem}")
        if part[0] == "cd":
            in_bootstrap_dir = len(part) == 2 and is_root_path(part[1], roots, BOOTSTRAP_DIR)
        part.clear()

    for token in tokens:
        if token == "&&":
            close_part()
        elif token in ("(", ")"):
            close_part()
            in_bootstrap_dir = False
        elif token and set(token) <= set("();&|<>"):
            return [f"{where} joins commands with `{token}`; only `&&` is allowed"]
        else:
            part.append(token)
    close_part()
    return problems


def check_command(text, where, roots=()):
    """Judge one shell-form command string."""
    if DYNAMIC.search(text):
        return [f"{where} uses a dynamic shell construct ($, backticks, a heredoc or a newline); deploy commands must be readable as written"]
    try:
        lexer = shlex.shlex(text, posix=True, punctuation_chars=True)
        lexer.whitespace_split = True
        lexer.commenters = ""
        tokens = list(lexer)
    except ValueError as exc:
        return [f"{where} could not be parsed as a shell command ({exc})"]
    return check_words(tokens, where, roots)


def iter_dockerfile_instructions(text):
    """(line number, INSTRUCTION, arguments). A trailing backslash continues the instruction,
    and blank and comment lines inside a continuation are skipped, as Docker does."""
    lines = text.splitlines()
    i = 0
    while i < len(lines):
        start, line = i + 1, lines[i]
        i += 1
        if not line.strip() or line.strip().startswith("#"):
            continue
        while line.rstrip().endswith("\\") and i < len(lines):
            nxt = lines[i]
            i += 1
            if not nxt.strip() or nxt.strip().startswith("#"):
                continue  # the line still ends with a backslash, so the continuation goes on
            line = line.rstrip()[:-1] + " " + nxt
        if line.rstrip().endswith("\\"):
            line = line.rstrip()[:-1]
        head = line.strip().split(None, 1)
        yield start, head[0].upper(), (head[1].strip() if len(head) > 1 else "")


def check_dockerfile_instruction(instruction, rest, where, roots):
    if instruction == "ONBUILD":
        inner = rest.split(None, 1)
        if not inner:
            return []
        return check_dockerfile_instruction(inner[0].upper(), inner[1] if len(inner) > 1 else "", f"{where} ONBUILD", roots)
    if instruction == "SHELL":
        return [f"{where} SHELL changes how every RUN is interpreted; deploy files may not set it"]
    if instruction == "HEALTHCHECK":
        words = rest.split(None, 1)
        while words and words[0].startswith("--"):
            words = words[1].split(None, 1) if len(words) > 1 else []
        if words and words[0].upper() == "CMD":
            return check_dockerfile_instruction("CMD", words[1] if len(words) > 1 else "", where, roots)
        return []
    if instruction in ("ENV", "ARG"):
        names = re.findall(r"(?:^|\s)([A-Za-z_][A-Za-z0-9_]*)(?==)", rest) if "=" in rest else rest.split()[:1]
        blocked = sorted({n for n in names if LOADER_VARS.match(n)})
        if blocked or re.search(r"npmrc", rest, re.IGNORECASE):
            return [f"{where} {instruction} sets {', '.join(blocked) or 'an npmrc path'}; npm configuration belongs in the committed .npmrc, and deploys may not change PATH, HOME or NODE_OPTIONS"]
        return []
    if instruction in ("COPY", "ADD"):
        words = [w for w in rest.split() if not w.startswith("--")]
        if any("npmrc" in os.path.basename(w.rstrip("/")).lower() for w in words):
            return [f"{where} {instruction} names an npmrc; npm configuration comes only from the committed .npmrc files"]
        if instruction == "ADD" and any(re.match(r"(?i)[a-z][a-z0-9+.-]*://|git@", w) for w in words):
            return [f"{where} ADD fetches from a URL; deploys get files only from the repository"]
        return []
    if instruction not in COMMAND_INSTRUCTIONS:
        return []
    while rest.startswith("--"):
        parts = rest.split(None, 1)
        rest = parts[1] if len(parts) > 1 else ""
    if rest.startswith("["):
        try:
            words = json.loads(rest)
        except ValueError:
            return [f"{where} has an exec-form {instruction} that is not valid JSON"]
        if not (isinstance(words, list) and words and all(isinstance(w, str) for w in words)):
            return [f"{where} has an exec-form {instruction} that is not a list of strings"]
        return check_words(words, where, roots)  # exec form runs no shell, so $ and backticks are literal
    return check_command(rest, where, roots)


def check_dockerfile(path, text):
    problems = []
    for line in text.splitlines():
        if not line.strip().startswith("#"):
            break
        if re.match(r"\s*#\s*escape\s*=", line, re.IGNORECASE):
            problems.append(f"{path} sets an escape parser directive; deploy files use Docker's default \\ escape")
    instructions = list(iter_dockerfile_instructions(text))
    roots = [rest.rstrip("/") for _, instruction, rest in instructions if instruction == "WORKDIR"][:1]
    for line, instruction, rest in instructions:
        problems += check_dockerfile_instruction(instruction, rest, f"{path}:{line}", roots)
    return problems


def check_vercel(path, text):
    try:
        data = json.loads(text)
    except (ValueError, RecursionError) as exc:
        return [f"{path} is not valid JSON ({type(exc).__name__})"]
    if not isinstance(data, dict):
        return [f"{path} is not a JSON object"]
    problems = []
    if not data.get("installCommand"):
        problems.append(f"{path} sets no installCommand, so Vercel would install with its own npm; install from tools/npm")
    for key in VERCEL_COMMANDS:
        value = data.get(key)
        if value is not None and not isinstance(value, str):
            problems.append(f"{path} {key} is not a string")
        elif value:
            problems += check_command(value, f"{path} {key}")
    build = data.get("build")
    for env in (data.get("env"), build.get("env") if isinstance(build, dict) else None):
        if isinstance(env, dict):
            for name in env:
                if LOADER_VARS.match(str(name)) or "npmrc" in str(name).lower():
                    problems.append(f"{path} env sets {name}; npm configuration belongs in the committed .npmrc")
    return problems


def scan_railway(path, text, tracked):
    """The dockerfilePath targets to scan, and problems with railway.ts itself."""
    targets, problems = [], []
    if SENSITIVE.search(text):
        problems.append(f"{path} mentions a package manager or an npmrc; Railway builds and starts through the Dockerfile and plain commands only")
    for key in re.findall(r"\b(startCommand|buildCommand|preDeployCommand|installCommand)\s*:", text):
        problems.append(f"{path} sets {key}; deploy commands belong in the Dockerfile, which this check reads")
    for builder in re.findall(r"\bbuilder\s*:\s*['\"]?([A-Za-z_]+)", text):
        if builder != "DOCKERFILE":
            problems.append(f"{path} uses builder {builder}; only DOCKERFILE builds are checked")
    for key, value in re.findall(r"\b(dockerfilePath|start)\s*:\s*([^\n]*)", text):
        literal = re.match(rf"({JS_STRING})\s*(?:,|}}|$)", value.strip())
        function = key == "start" and re.match(rf"encodeFunctionScript\(\s*({JS_STRING})\s*\)\s*(?:,|}}|$)", value.strip())
        if not (literal or function):
            problems.append(f"{path} sets {key} to {value.strip()[:40]!r}, which is not a plain string; write it as one so it can be checked")
            continue
        string = (literal or function).group(1)[1:-1]
        if "\\" in string:
            problems.append(f"{path} sets {key} with an escape sequence; write it plainly so it can be checked")
        elif key == "start" and literal:
            problems += check_command(string, f"{path} start")
        elif key == "dockerfilePath":
            if string not in tracked:
                problems.append(f"{path} builds from {string}, which is not a tracked file")
            else:
                targets.append(string)
    return targets, problems


def is_deploy_name(path):
    name = os.path.basename(path).lower()
    return (
        name in ("dockerfile", "containerfile", "vercel.json")
        or re.match(r"(dockerfile|containerfile)[._-]", name) is not None
        or name.endswith((".dockerfile", ".containerfile"))
    )


def read_text(path):
    if os.path.islink(path):
        raise OSError("is a symlink; deploy files must be regular files")
    try:
        with open(path, encoding="utf-8") as fh:
            return fh.read()
    except UnicodeDecodeError as exc:
        raise OSError(f"is not UTF-8 ({exc.reason})") from exc


def find_deploy_problems(tracked_blob):
    """Returns (problems, number of deploy files checked)."""
    tracked = [p for p in tracked_blob.split("\0") if p]
    tracked_set = set(tracked)
    files = [p for p in tracked if is_deploy_name(p)]
    problems = []
    railway = ".railway/railway.ts"
    if railway in tracked_set:
        try:
            targets, railway_problems = scan_railway(railway, read_text(railway), tracked_set)
        except OSError as exc:
            targets, railway_problems = [], [f"{railway} could not be read ({exc})"]
        problems += railway_problems
        files += [t for t in targets if t not in files]
    for path in files:
        try:
            text = read_text(path)
        except OSError as exc:
            problems.append(f"{path} could not be read ({exc})")
            continue
        if os.path.basename(path).lower() == "vercel.json":
            problems += check_vercel(path, text)
        else:
            problems += check_dockerfile(path, text)
    return problems, len(files)


def main():
    problems, checked = find_deploy_problems(sys.stdin.read())
    for line in problems:
        print(line)
    if not checked:
        print("found no deploy file to check (no Dockerfile, Containerfile or vercel.json is tracked)")
        return 1
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
