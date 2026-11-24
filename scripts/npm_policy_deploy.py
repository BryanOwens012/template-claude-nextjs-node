#!/usr/bin/env python3
"""npm_policy_deploy.py — the deploy-file half of check-npm-policy.sh, as an allowlist.

The rule (CLAUDE.md, "npm 12 is required"): deploys install dependencies only with the npm
bootstrapped from tools/npm, never fetch npm itself, and never change npm's configuration. A
deny-list of bad spellings cannot hold that, since a shell has endless ways to spell a command,
so this module allows a short list of known command shapes and refuses everything else that
touches npm. Unknown shapes fail closed by construction.

A deploy command (each RUN, CMD, ENTRYPOINT, HEALTHCHECK and ONBUILD in a Dockerfile, each
command in vercel.json, each `start` string in .railway/railway.ts) is refused when it uses a
dynamic construct ($, backticks, a heredoc, eval, source, exec, xargs, a newline) or starts a
nested shell. Otherwise it passes when it mentions no package manager and no npm configuration,
or is a chain of `&&`-joined simple commands, grouped at most by parentheses, each of which
mentions none or is one of the ALLOWED_SHAPES. ENV and ARG may not set npm configuration, COPY
and ADD may not name an npmrc, SHELL is refused, and vercel.json env may not set npm
configuration.

This holds deploy files to a reviewable shape; it is not a sandbox. A build step that runs a
committed script or an interpreter (`node build.js`, `sh build.sh`) runs whatever that file
does, and that file is reviewed as code, not by this check.

Standard library only. Called through `npm_policy.py deploy`, with NUL-separated tracked paths
(`git ls-files -z`) on stdin.
"""

import json
import os
import re
import shlex

BOOTSTRAP_DIR = "tools/npm"
BOOTSTRAP_BIN = "tools/npm/node_modules/.bin/npm"
# Words that mean a command touches npm, another package manager, or npm configuration.
SENSITIVE = re.compile(
    r"(?<![A-Za-z0-9_.-])(npm|npx|pnpm|yarn|bun|corepack)(?![A-Za-z0-9_-])|npm_config|\.npmrc",
    re.IGNORECASE,
)
# Constructs that let a command compute what it runs; a deploy command must be readable as text.
DYNAMIC = re.compile(r"[$`]|<<|(?<![A-Za-z0-9_-])(eval|source|exec|xargs)(?![A-Za-z0-9_-])")
SHELLS = {"sh", "bash", "zsh", "dash", "ash", "ksh"}
CI_FLAGS = {"--no-audit", "--no-fund"}
SCRIPT_NAME = re.compile(r"[A-Za-z0-9][A-Za-z0-9:._-]*")
ALLOWED_SHAPES = (
    f"`cd <dir>/{BOOTSTRAP_DIR} && npm ci` (the bootstrap), "
    f"`<dir>/{BOOTSTRAP_BIN} ci` or `... run <script>`, `npm run <script>`, `npx tsc`"
)
COMMAND_INSTRUCTIONS = {"RUN", "CMD", "ENTRYPOINT"}
VERCEL_COMMANDS = ("installCommand", "buildCommand", "devCommand", "ignoreCommand")


def is_bootstrap_bin(word):
    return word == BOOTSTRAP_BIN or word.endswith("/" + BOOTSTRAP_BIN)


def is_bootstrap_dir(word):
    path = word.rstrip("/")
    return path == BOOTSTRAP_DIR or path.endswith("/" + BOOTSTRAP_DIR)


def starts_nested_shell(tokens):
    """A shell at command position (first word, or after a separator) or given an option."""
    for i, token in enumerate(tokens):
        if os.path.basename(token) not in SHELLS:
            continue
        at_start = i == 0 or (tokens[i - 1] and set(tokens[i - 1]) <= set("();&|"))
        if at_start or (i + 1 < len(tokens) and tokens[i + 1].startswith("-")):
            return True
    return False


def is_allowed_part(words, in_bootstrap_dir):
    """True when one simple command is an allowed npm shape (or touches no npm at all)."""
    if not SENSITIVE.search(" ".join(words)):
        return True
    prog, args = words[0], words[1:]
    if prog == "npm" and in_bootstrap_dir and args[:1] == ["ci"] and set(args[1:]) <= CI_FLAGS:
        return True
    if is_bootstrap_bin(prog):
        if args[:1] == ["ci"] and set(args[1:]) <= CI_FLAGS:
            return True
        if len(args) == 2 and args[0] == "run" and SCRIPT_NAME.fullmatch(args[1]):
            return True
    if prog == "npm" and len(args) == 2 and args[0] == "run" and SCRIPT_NAME.fullmatch(args[1]):
        return True
    return words == ["npx", "tsc"]


def check_words(tokens, where):
    """Judge a tokenized command (shell tokens, or an exec-form word list)."""
    if starts_nested_shell(tokens):
        return [f"{where} runs a nested shell; deploy commands must be readable as written"]
    if not SENSITIVE.search(" ".join(tokens)):
        return []
    problems = []
    part, in_bootstrap_dir = [], False

    def close_part():
        nonlocal in_bootstrap_dir
        if not part:
            return
        if part[0] == "cd" and len(part) == 2:
            in_bootstrap_dir = is_bootstrap_dir(part[1])
        elif not is_allowed_part(part, in_bootstrap_dir):
            problems.append(f"{where} runs `{' '.join(part)}`, which is not an allowed npm command (allowed: {ALLOWED_SHAPES})")
        part.clear()

    for token in tokens:
        if token == "&&":
            close_part()
        elif token in ("(", ")"):
            close_part()
            in_bootstrap_dir = False
        elif token and set(token) <= set("();&|<>"):
            return [f"{where} joins npm commands with `{token}`; only `&&` is allowed there"]
        elif not part and "=" in token and re.match(r"^[A-Za-z_][A-Za-z0-9_]*=", token):
            return [f"{where} sets a variable inline in an npm command; set npm configuration only in .npmrc"]
        else:
            part.append(token)
    close_part()
    return problems


def check_command(text, where):
    """Judge one shell-form command string."""
    if DYNAMIC.search(text) or "\n" in text or "\r" in text:
        return [f"{where} uses a dynamic shell construct ($, backticks, a heredoc, eval, source, exec, xargs or a newline); deploy commands must be readable as written"]
    try:
        lexer = shlex.shlex(text, posix=True, punctuation_chars=True)
        lexer.whitespace_split = True
        lexer.commenters = ""
        tokens = list(lexer)
    except ValueError as exc:
        return [f"{where} could not be parsed as a shell command ({exc})"]
    return check_words(tokens, where)


def iter_dockerfile_instructions(text):
    """(line number, INSTRUCTION, arguments), joining continuations and dropping comment lines
    inside them, as Docker does."""
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
            if nxt.strip().startswith("#"):
                continue
            line = line.rstrip()[:-1] + " " + nxt
        head = line.strip().split(None, 1)
        yield start, head[0].upper(), (head[1].strip() if len(head) > 1 else "")


def check_dockerfile_instruction(instruction, rest, where):
    if instruction == "ONBUILD":
        inner = rest.split(None, 1)
        return check_dockerfile_instruction(inner[0].upper(), inner[1] if len(inner) > 1 else "", f"{where} ONBUILD") if inner else []
    if instruction == "SHELL":
        return [f"{where} SHELL changes how every RUN is interpreted; deploy files may not set it"]
    if instruction == "HEALTHCHECK":
        words = rest.split(None, 1)
        while words and words[0].startswith("--"):
            words = words[1].split(None, 1) if len(words) > 1 else []
        if words and words[0].upper() == "CMD":
            return check_dockerfile_instruction("CMD", words[1] if len(words) > 1 else "", where)
        return []
    if instruction in ("ENV", "ARG"):
        if re.search(r"npm_config_|npmrc", rest, re.IGNORECASE):
            names = re.findall(r"(?i)\b(npm_config_[A-Za-z0-9_]*)", rest) or ["npm configuration"]
            return [f"{where} {instruction} sets {', '.join(sorted(set(names)))}; npm configuration belongs in the committed .npmrc"]
        return []
    if instruction in ("COPY", "ADD"):
        if any("npmrc" in os.path.basename(w.rstrip("/")).lower() for w in rest.split() if not w.startswith("--")):
            return [f"{where} {instruction} names an npmrc; npm configuration comes only from the committed .npmrc files"]
        return []
    if instruction not in COMMAND_INSTRUCTIONS:
        return []
    while rest.startswith("--"):
        rest = rest.split(None, 1)[1] if " " in rest else ""
    if rest.startswith("["):
        try:
            words = json.loads(rest)
        except ValueError:
            return [f"{where} has an exec-form {instruction} that is not valid JSON"]
        if not (isinstance(words, list) and all(isinstance(w, str) for w in words)):
            return [f"{where} has an exec-form {instruction} that is not a list of strings"]
        return check_words(words, where)  # exec form runs no shell, so $ and backticks are literal
    return check_command(rest, where)


def check_dockerfile(path, text):
    problems = []
    for line, instruction, rest in iter_dockerfile_instructions(text):
        problems += check_dockerfile_instruction(instruction, rest, f"{path}:{line}")
    return problems


def check_vercel(path, text):
    try:
        data = json.loads(text)
    except (ValueError, RecursionError) as exc:
        return [f"{path} is not valid JSON ({type(exc).__name__})"]
    if not isinstance(data, dict):
        return [f"{path} is not a JSON object"]
    problems = []
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
                if re.search(r"npm_config_|npmrc", str(name), re.IGNORECASE):
                    problems.append(f"{path} env sets {name}; npm configuration belongs in the committed .npmrc")
    return problems


def check_railway(path, text, tracked):
    """The dockerfilePath targets to scan, and problems with railway.ts's own start commands."""
    targets, problems = [], []
    for key in re.findall(r"\b(dockerfilePath|start)\s*:\s*`", text):
        problems.append(f"{path} sets {key} with a template string; write it as a plain quoted string so it can be checked")
    for target in re.findall(r"dockerfilePath\s*:\s*['\"]([^'\"]+)['\"]", text):
        if target not in tracked:
            problems.append(f"{path} builds from {target}, which is not a tracked file")
        else:
            targets.append(target)
    for command in re.findall(r"\bstart\s*:\s*['\"]([^'\"]*)['\"]", text):
        problems += check_command(command, f"{path} start")
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
    with open(path) as fh:
        return fh.read()


def run(tracked_blob):
    """Returns (problems, number of deploy files checked)."""
    tracked = [p for p in tracked_blob.split("\0") if p]
    tracked_set = set(tracked)
    files = [p for p in tracked if is_deploy_name(p)]
    problems = []
    railway = ".railway/railway.ts"
    if railway in tracked_set:
        try:
            targets, railway_problems = check_railway(railway, read_text(railway), tracked_set)
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
