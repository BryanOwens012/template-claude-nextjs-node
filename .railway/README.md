# Railway Infrastructure as Code

`railway.ts` in this directory declares the whole Railway environment for this project: the `API` service, its `Redis` database, and the `Keep-Alive` scheduled function. It replaces the deprecated `railway.json` (Config as Code stops being read on 2026-12-01).

## Workflow

Requires the Railway CLI 5.42.1 or newer and `npm install` at the repo root (the file imports the `railway` package).

```bash
railway login
railway link                 # once per clone: pick the project + environment
railway config plan          # read-only diff; safe to run any time
railway config apply         # re-plans, then applies after you confirm
```

From an unlinked clone, `plan` prompts for the project and environment. The `config` subcommands accept no `-p`/`-e` flags; to run non-interactively (CI, an agent session), pass the ids as environment variables:

```bash
RAILWAY_PROJECT_ID=<project-id> RAILWAY_ENVIRONMENT_ID=<environment-id> railway config plan </dev/null
```

Get the ids from `railway list --json`. Run `railway` directly rather than through a wrapper that `exec`s it: the SDK checks the CLI version via the executable named in `$_`, so a wrapper makes it fail with "requires Railway CLI 5.42.1 or newer".

- `plan` redacts variable values; add `--show-values` to print them.
- `apply --yes` is non-interactive; destructive changes (deleting a service or variable) additionally require `--confirm-destructive`.
- Typecheck the file against the SDK's types with `npm run typecheck:railway` — an unknown key is a type error here, whereas Railway may ignore it silently.

## Rules

- **Omit means delete.** Every service, database, and variable in the environment must be declared, or `apply` removes it. Read the plan's destroy lines before confirming.
- **Secrets stay in Railway.** Declare them as `preserve()` so the plan keeps whatever value is set in the dashboard. Never write a secret value into this file.
- **One file per project.** Do not add a second authoring file (`railway.py`, `railway.go`) or a `partial` export.
- **Function code lives in the repo.** `Keep-Alive` runs `apps/cron/src/keep-alive.ts`; the file is base64-encoded into the function's start command at plan time, so editing the script shows up as a diff.

Docs: [Infrastructure as Code](https://docs.railway.com/infrastructure-as-code), [DSL reference](https://docs.railway.com/infrastructure-as-code/reference), [`railway config`](https://docs.railway.com/cli/config).
