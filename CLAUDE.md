# Claude Code Instructions

As a reference, this file is organized as follows: **Project Overview** → what this template is and its tech stack; **Development Guidelines** → how to behave and work (respond in words first; be liberal with tools/MCPs), code quality, TS/React/Express style, dependency management, code organization, testing, security posture, destructive-deletion and shell option-injection guards, performance & prefetching, and git workflow; **LLM Model Selection** + **LLM Calls** → model/reasoning-choice doctrine, routing through OpenRouter (Vercel AI Gateway as the alternative), prompt caching + cache pre-warming, and Langfuse tracing/prompt policy + integration patterns; **Common Pitfalls** → frequent mistakes to avoid; **Deployment** → Vercel (web) and Railway (api); **Project-Specific Patterns** → env vars, tRPC integration, CORS, SQL migrations, Supabase types/keys; **Verification Checklist** → pre-completion gates; **Agent Session Logging** + **Agent Collaboration** → multi-agent etiquette; **Template Customization** → how to adapt this template to a new project.

## Project Overview

This is a Next.js + Node.js template for rapidly spinning up full-stack applications.

**Status**: Template repository (ready for customization)

### Tech Stack

- **Frontend**:
  - Next.js 16+ (App Router, React Server Components)
  - React 19
  - TypeScript 6+
  - Tailwind CSS v4 (CSS-first config: `@theme` in `globals.css`, no `tailwind.config.ts`; PostCSS plugin is `@tailwindcss/postcss`, autoprefixer not needed)
  - Radix UI, shadcn/ui
  - TanStack Query v5

- **Backend**:
  - Express 5 (Node.js 24+)
  - TypeScript with ESM modules ("type": "module")
  - tRPC v11 for end-to-end type-safe API procedures
  - Zod for runtime validation and type safety
  - ioredis for caching
  - Supabase JS client (secret key for server-side operations)
  - Langfuse for LLM observability (optional: tracing, sessions; prompts live in the codebase, not Langfuse)

- **Deployment**:
  - Frontend: Vercel (auto-configured via vercel.json)
  - Backend: Railway (declared as Infrastructure as Code in `.railway/railway.ts`)

### Development Philosophy

- **Code Quality First**: Always test after changes, fix all TypeScript errors before committing
- **Modern Syntax**: Use latest ES6+ and Node.js 24+ features
- **AI-Assisted**: Leverage AI for rapid development while maintaining high standards

## Development Guidelines

### Respond in Words Before Acting

At the start of every turn, before the first tool call (exploring, running commands, editing files), give a brief response in words: confirm what was understood, validate the approach, or push back if the request seems wrong — then start working. One or two sentences is enough; this is an FYI/acknowledgment, not a plan. It applies even when work begins immediately afterward — never open a turn with silent tool use.

### Tools, CLIs & MCP Servers (Be Liberal)

Be liberal with calling tools, CLI commands, and MCP servers to make changes and to diagnose and solve problems. This is particularly true when diagnosing build or deploy failures.

- **Reach for the platform's MCP server / CLI.** This repo deploys to Vercel (web) and Railway (api) — install and use their MCP servers (if not already installed) when diagnosing deploys. Analogously for Figma, Framer, AWS, GCP, Azure, Supabase, Datadog, etc. if the project uses them. The repo-root `.mcp.json` preconfigures the Vercel, Railway, and Supabase MCP servers (Supabase runs read-only and needs `SUPABASE_ACCESS_TOKEN` in your environment).
- **Destructive actions still require approval.** Be liberal with read-only, diagnostic, and safely reversible actions — but always ask for the user's approval before executing destructive actions (deletes, rollbacks, production config/env changes, force operations, etc.).
- **Suggest `/goal` for goal-driven runs.** When a task is the kind that should run until done (e.g., fully fixing a deploy failure), suggest that the user can give the `/goal` slash-command to command you to keep working until the goal is reached.

### Code Quality Standards

- **Always test after every change** - Run the application and verify functionality works
- **Build before committing** - Ensure builds pass without errors
- **Fix all type errors** - No ignoring TypeScript type errors
- **Never hallucinate** - Don't assume files, functions, or APIs exist. Read and verify first
- **Read before writing** - Always use Read tool to check existing code before making changes

### JavaScript/TypeScript Style

- Use **TypeScript** for all new code with proper type definitions
- Use **arrow functions** for all function expressions: `const foo = () => {}`
- Use **modern ES6+ syntax**:
  - Destructuring: `const { foo, bar } = obj`
  - Template literals: `` `Hello ${name}` ``
  - Spread operator: `{ ...obj, newProp: value }`
  - Optional chaining: `obj?.property?.nested`
  - Nullish coalescing: `value ?? defaultValue`
- Prefer `const` over `let`, never use `var`
- Use async/await instead of promise chains (prefer `async`/`await` over `.then()`)
- Prefer functional array methods: `map`, `filter`, `reduce`
- **Arrow notation**: use arrow function notation whenever possible — with the understanding that sometimes (e.g. component lifecycle functions) standard `function` notation is necessary
- **String union types** — derive them from a `const` array so the values also exist at runtime:
  - Bad: `type Val = 'a' | 'b' | 'c'`
  - Good: `const vals = ['a', 'b', 'c'] as const; type Val = (typeof vals)[number];`
- **Handle empties deliberately**: make sure all empty strings, empty lists, empty objects, `null`s, and `undefined`s are handled correctly. Make sure `||` and `??` (and similar operators) have exactly the right scope — not too tight, not too lax (`||` also coerces `''`, `0`, and `false`; `??` only `null`/`undefined`)
- **Function names start with a verb** for every function that is not a React function component (predicates may use `is`/`has`/`can` prefixes). This conforms to function naming conventions
- **File size**: there should be few files with >700 lines of code. Whenever a file exceeds 700 lines, consider whether breaking it up would improve organization and separation of concerns — feel free to create new files, folders, and subfolders with names that make sense

### Express/Node.js Style

- Use **ESM imports** with explicit `.js` extensions in TypeScript source files (e.g., `import { foo } from "@/lib/bar.js"`)
  - TypeScript doesn't rewrite extensions; Node.js ESM requires them
  - Symptom of missing extension: `Error: Cannot find module` at startup
- Define **Zod schemas** for request/response validation, not types (types are inferred from schemas)
- Use `getEnvironment()` from `config/environment.ts` for environment variables (never use `process.env` directly)
- Define **tRPC procedures** using `publicProcedure.input(Schema).output(Schema).query(...)` or `.mutation(...)`
- Use **TRPCError** for procedure errors: `throw new TRPCError({ code: 'BAD_REQUEST', message: '...' })`
- Return data directly from procedures — tRPC handles serialization (no `res.json()`)

### Node.js Dependency Management

**CRITICAL: Always commit package-lock.json after installing packages**

When you install a new package:

1. Navigate to the service directory: `cd apps/api`
2. Install the package: `npm install <package-name>`
3. Commit the updated `package.json` and `package-lock.json`
4. For CI/CD, use `npm ci` (requires committed lockfile) instead of `npm install`

**For this monorepo:**

- Each service under `apps/` has its own `package.json` and `package-lock.json`
- `apps/api/package.json` - Node.js dependencies for the API service
- Each service is independently deployable with its own dependencies
- If you add a new service, create its own `package.json`

**Example workflow:**

```bash
# Navigate to service directory
cd apps/api

# Install new package
npm install <new-package>

# Commit package.json and package-lock.json
git add package.json package-lock.json
git commit -m "Add <new-package> dependency"
```

**DO NOT:**

- ❌ Install packages without committing package-lock.json
- ❌ Use outdated or conflicting versions
- ❌ Commit code that requires packages not in package.json
- ❌ Gitignore package-lock.json (it must be committed)

### React Best Practices

- Use **functional components** with hooks only
- Follow React Server Components patterns where possible
- Use `"use client"` directive only when necessary (client-side interactivity required)
- Properly handle loading and error states
- Clean up effects with return functions
- Use proper dependency arrays for hooks

### Component Development

- Place reusable UI components in appropriate directories
- Define TypeScript interfaces for all props
- Use descriptive, semantic names
- Keep components focused and single-purpose
- Follow accessibility best practices (ARIA labels, semantic HTML)
- **Boolean prop names** — props whose value is a boolean (or whose handler takes or returns a boolean) should start with `is`, `has`, `was`, `had`, `can`, `did`, `could`, or `should` (e.g. `isOpen`, `hasError`, `wasEdited`, `canEdit`, `didSubmit`, `couldRetry`, `shouldRender`)
- **Prefer shadcn components**: prefer shadcn (or at least shadcn-inspired) components, to make the UI components more readable, composable, and extensible
- **Frontend contrast (WCAG)**: regardless of light mode or dark mode, all text must be visible on its background color, and all contrast must meet WCAG requirements
- **Supabase + Zod**: when a project uses Supabase generated types and Zod schemas, use the Supabase generated types and Zod schemas (with `safeParse`) as much as possible

### API Development

- Create tRPC sub-routers in `src/trpc/routers/` for logical groupings of procedures
- Use consistent naming conventions (RESTful when appropriate)
- Version APIs when making breaking changes
- Include health check procedure (`health.check` query) and minimal `/health` Express endpoint for infrastructure probes
- Add comprehensive error handling

### Code Organization

**Frontend:**

```
apps/web/
├── app/                  # Next.js app router
│   ├── (auth)/          # Auth pages (login, signup, reset-password, etc.)
│   │   ├── login/page.tsx
│   │   ├── signup/page.tsx
│   │   ├── reset-password/page.tsx
│   │   ├── update-password/page.tsx
│   │   ├── auth/callback/route.ts       # OAuth callback handler
│   │   ├── auth/auth-code-error/page.tsx
│   │   └── layout.tsx
│   ├── (dashboard)/     # Protected dashboard pages
│   │   ├── dashboard/page.tsx
│   │   └── layout.tsx   # Auth guard + header
│   ├── .well-known/     # Microsoft domain verification
│   ├── page.tsx         # Home page
│   └── layout.tsx       # Root layout (wraps children with TRPCProvider)
├── components/           # React components
│   ├── providers/       # Context providers
│   │   └── TRPCProvider.tsx  # tRPC + TanStack Query + auth headers
│   ├── ui/
│   │   └── LoadingDialog.tsx # 200ms-delayed, scrim-less loading dialog + useDelayedLoading
│   ├── PagePrefetcher.tsx    # Mounted in root layout; prefetches all other top-level pages
│   └── LogoutButton.tsx
├── lib/                 # Utilities and helpers
│   ├── prefetch/        # Aggressive prefetching primitives
│   │   ├── routes.ts    # topLevelRoutes const (register new top-level pages here)
│   │   ├── usePrefetchPages.ts      # Top-level pages: routes + data queries
│   │   ├── useHoverPrefetch.ts      # 200ms hover-intent row prefetch handlers
│   │   ├── usePaginationPrefetch.ts # Warm next + previous paginated pages
│   │   └── idle.ts      # runWhenIdle (requestIdleCallback wrapper)
│   ├── supabase/        # Supabase clients
│   │   ├── client.ts    # Browser client
│   │   ├── server.ts    # Server client (RSC)
│   │   ├── middleware.ts # Session updater (proxy)
│   │   ├── service.ts   # Admin client (secret key)
│   │   └── check-invite.ts  # Invitation gating (server action)
│   ├── utils/admin.ts   # Admin email domain check
│   └── trpc.ts          # tRPC client context (useTRPC hook)
├── public/sso/          # OAuth provider logos (Google, Microsoft SVGs)
└── proxy.ts             # Next.js 16 middleware (route protection)
```

**Backend:**

```
apps/api/
├── package.json         # Node.js dependencies and scripts
├── tsconfig.json        # TypeScript configuration (rootDir: "..")
├── src/
│   ├── index.ts         # Express app + tRPC mount + server start
│   ├── config/
│   │   └── environment.ts        # Zod env validation, lazy singleton, getCorsOrigins()
│   ├── middleware/
│   │   ├── cors.ts              # CORS configuration with localhost passthrough
│   │   └── errorHandler.ts      # Centralized error handling (400s, ZodError, 500)
│   ├── prompts/
│   │   └── index.ts             # LLM prompts (codebase source of truth) + getPrompt/compilePrompt
│   ├── trpc/
│   │   ├── init.ts              # tRPC context (req/res), createRouter, publicProcedure, middleware
│   │   ├── middleware.ts        # Auth middleware (authenticatedProcedure, adminProcedure, etc.)
│   │   ├── router.ts            # Root router merging sub-routers, exports AppRouter type
│   │   └── routers/
│   │       ├── health.ts        # health.check query
│   │       ├── info.ts          # info.get query (API name/version/status)
│   │       ├── langfuse.ts      # langfuse.test, langfuse.getPrompt, langfuse.traceExample
│   │       ├── redis.ts         # redis.test, redis.cacheSet, redis.cacheGet, redis.cacheDelete
│   │       └── supabase.ts      # supabase.test query
│   ├── services/
│   │   ├── langfuse.ts          # initLangfuse/getLangfuse/isLangfuseAvailable (tracing only)
│   │   ├── redis.ts             # initRedis/closeRedis/getRedisClient/isRedisAvailable
│   │   ├── supabase.ts          # initSupabase/getSupabaseClient/isSupabaseAvailable
│   │   └── telemetry.ts         # OpenTelemetry SDK with LangfuseSpanProcessor
│   └── types/
│       └── index.ts             # Zod schemas + z.infer<> types (input + output)
├── Dockerfile           # Docker build (node:24-alpine, used by Railway)
└── .env.example         # Environment variable template

apps/shared/
└── supabase/            # Compiled into apps/api (tsconfig rootDir: "..") and resolved by apps/web as @shared/*
    ├── types.ts         # Generated; regenerate with scripts/gen-supabase-types.sh
    └── migrations/      # .up.sql/.down.sql pairs, run by hand in the Supabase SQL Editor
```

**Root:**

```
vercel.json            # Vercel deployment config for web app (simplified)
.railway/railway.ts    # Railway Infrastructure as Code: API (Dockerfile → apps/api/Dockerfile), Redis, Keep-Alive
.railway/tsconfig.json # Typechecks railway.ts against the `railway` SDK (npm run typecheck:railway)
.claude/gauntlet.json  # Declared pre-merge quality gate, cheapest check first (check:hooks)
.husky/                # pre-commit, plus post-merge/post-rewrite/post-checkout/post-commit lockfile sync
scripts/
├── install-changed-lockfiles.sh  # Shared by the four sync hooks: npm install per changed lockfile
├── check-hooks-installed.sh      # npm run check:hooks — fails when git would run no hooks here
├── new-worktree.sh               # npm run worktree:new — worktree + npm ci + api build + hook check
├── run-shell-tests.sh            # npm run test:scripts:sh — finds and runs every *.test.sh, bounded
└── tests/*.test.sh               # bash suites for the scripts above, sandboxed, npm stubbed
```

### Testing Workflow

1. Make a change
2. **Test immediately** in the browser/application
3. Verify the specific functionality works
4. Check for unintended side effects
5. Run build/tests to catch errors
6. Only proceed to next change after current one works

### Error Handling

- Handle errors gracefully with try/catch
- Provide meaningful error messages
- Log errors appropriately for debugging
- Don't silently swallow errors
- Return proper HTTP status codes from APIs

### Security Posture

- **Least privilege (tightest scope)**: always keep security to the tightest (minimal scope) possible that still accomplishes all our goals. Grant exactly the access needed and nothing more. This applies to Supabase RLS/policies, GRANTs, and roles, as well as to code (API surface, permissions, env access, etc.).
- **Fail-closed, not fail-open**: when an error occurs, the default must be to block access rather than grant it. Never let a failure path fall through to allowing an action; on any uncertainty or error, deny.

### Destructive Deletion Commands (`rm -rf`) — Extreme Caution

Be extremely careful whenever writing `rm -rf` — or any other recursive/forced deletion (`rm -r`, `rm -f`, `find … -delete`, `git clean -fdx`, Node's `fs.rm`/`fs.rmSync` with `recursive: true`/`force: true`, Python's `shutil.rmtree`, etc.). This applies to **all code and all test files in the repo** — shell scripts, npm scripts, CI workflows, test setup/teardown, launchers, one-off commands — not just interactive terminal use. A single bad path deletes work irrecoverably; treat every recursive delete as a loaded weapon.

**Always add guards so a deletion can never touch anything it isn't supposed to:**

- **Never delete through an unvalidated variable.** In shell, an unset or empty variable silently widens the target — `rm -rf "$DIR/build"` with `DIR` unset becomes `rm -rf /build`. Use `set -u` and the `${VAR:?}` expansion (`rm -rf "${DIR:?}/build"`) so an unset/empty variable aborts the script instead of expanding to nothing. Same idea in every language: validate the path is non-empty before deleting.
- **Assert the target is inside an expected parent.** Resolve the path to absolute form and verify it lives under the directory it's supposed to (the repo, a temp dir, a build dir) before deleting. Explicitly refuse obviously catastrophic targets: `/`, `$HOME`, the repo root, and anything reached via `..`.
- **Require the target to look like what you expect.** Before a recursive delete, check for a marker (the expected directory name, a known file inside it) so a mis-set variable that points somewhere valid-but-wrong still gets caught. The shell suites in `scripts/tests/` do this: each `cleanup()` matches its sandbox against the `mktemp` template it was created with (`*/lockfile-hooks.??????`) before `rm -rf -- "$SB"`, so a clobbered `SB` deletes nothing.
- **Prefer the narrowest deletion that works.** Delete specific known files over globs, globs over whole directories; reach for a recursive directory delete only when the entire directory is genuinely disposable. Never combine a variable and a wildcard (`rm -rf "$DIR"/*`) without both the variable guard and the parent-path check.
- **In tests, delete only inside dedicated temp directories.** Test setup/teardown must create and remove files under `mktemp -d` (or the test framework's tmp helpers) — never point cleanup at repo paths, shared fixtures, or user data.
- **Worktrees and build output have their own tools.** Remove a worktree with `git worktree remove <path>` then `git worktree prune`, never `rm -rf` on the directory, which orphans its admin state under `.git/worktrees`. Reclaim `.next` and other regenerable caches with `bash ~/.claude/build-output.sh clean` (dry-run first), which resolves the path, confirms it sits inside this clone, and skips any tree with a live dev server; `node_modules` is never a deletion target.
- **Fail closed.** If any guard can't be verified — the path doesn't resolve, the variable is empty, the marker is missing — abort the deletion loudly rather than proceeding (see **Security Posture**).

### Shell Option-Injection Guards (`--` Before Path Operands)

A filename or variable that starts with `-` gets parsed as an **option**, not an operand — `mv "$f" dest` with `f=-n.md` silently becomes a no-clobber flag, `dirname "-x.md"` errors out, and a glob like `rm *` can expand a file literally named `-rf` into flags. This bites most often in shell scripts, where filenames come from variables, arguments, or globs rather than being typed by hand.

- **Put `--` (end-of-options) before every path operand that isn't a hardcoded literal**: `mv -- "$src" "$dst"`, `rm -- "$f"`, `cp -- "$a" "$b"`, `dirname -- "$p"`, `basename -- "$p"`, `git checkout -- "$path"`, `grep -e "$pattern"` (grep's `--` equivalent for the pattern operand).
- **Where a tool doesn't support `--`** (or you're unsure), anchor the path instead: prefix relative paths with `./` (`rm "./$f"`), or use absolute paths — an operand starting with `/` or `./` can never be parsed as an option.
- **`echo "$var"` has the same bug** (`-n`, `-e` swallowed) plus escape-handling drift across shells — use `printf '%s\n' "$var"` for variable output.

### Performance Considerations

- Lazy load components when appropriate
- Memoize expensive computations
- Avoid unnecessary re-renders
- Optimize images and assets
- Monitor bundle size
- Use database indexes for common queries
- Cache API responses when appropriate

### Aggressive Prefetching (Pages & Queries)

In web apps, prefetch aggressively so navigation feels instant — regardless of the size of the app (e.g. the number of pages). "Prefetch" always means **both** the frontend (route/components/bundle) **and** warming the underlying data queries — prefetching the UI shell without its data is only half the job. All prefetching must be background, deferred, and non-blocking: it must never delay or compete with rendering the page the user is actually on.

- **Top-level pages**: when the user lands on any top-level page, prefetch all the other top-level pages.
- **Tabs**: when the user lands on a top-level page that has tabs, prefetch all the other tabs of that page.
- **Table rows (hover intent)**: on a page/tab with a table, if the user hovers over a row for more than 200ms, prefetch the result of clicking that row.
- **Paginated tables**: when the user is on one page of a paginated table, prefetch the contents and queries of the next and previous pages.

#### Loading Indicators (When Loading Is Unavoidable)

When a user action (clicking a button, etc.) triggers loading, show a small loading dialog only if the loading takes more than 200ms — never instantly. Do **not** accompany the loading dialog with a scrim/backdrop: the scrim causes a flash, and that flash is bad UI.

The template ships reusable primitives for this doctrine in `apps/web/lib/prefetch/` (route + tRPC query prefetching, hover-intent row prefetch, paginated next/prev warming) and `apps/web/components/ui/LoadingDialog.tsx` (the 200ms-delayed, scrim-less loading dialog) — use them rather than reinventing.

### Git Workflow

- Make small, focused commits
- Write clear, descriptive commit messages
- Don't commit untested code
- Keep commits atomic and reversible
- Use conventional commit format when possible

**Starting new feature work:**

- If on the `main` branch and asked to build a new feature, do not start working on `main`. First pull the latest `origin/main`, then check out a new branch (following the branch naming convention below), with the end goal of opening a new PR.

**Branch naming:**

- When creating a new git branch on the human contributor's behalf, prefix the name with their nickname `bryan` (the human contributor, not the agent/assistant), followed by a slash and a short kebab-case description (e.g. `bryan/add-export-button`).

**Pull requests:**

- When opening a new PR on the human contributor's behalf, assign it to them (e.g. `gh pr create --assignee @me`, where `@me` resolves to the authenticated GitHub user — the human contributor, not the agent/assistant).

**Git hooks (husky, committed under `.husky/`):**

- **Hooks arm on the first ROOT `npm install`** (`prepare: husky` writes the gitignored `.husky/_` dispatchers). A per-app install does not arm them. `npm run check:hooks` says whether git would run any hooks in this tree; run it the moment a commit sails through without the checks you expected, and always in a new worktree.
- **Create worktrees with `npm run worktree:new -- <path> <branch> [base]`**, never a bare `git worktree add`: the bare form inherits `core.hooksPath` from the shared config while `.husky/_` does not exist there, so git runs no hooks and reports nothing. The script installs every workspace (root first), builds the API that `apps/web` resolves `@api/*` against, and fails unless `check:hooks` passes.
- **`pre-commit` runs `npm run typecheck` then `npx lint-staged`.** Keep `typecheck` the single definition of what must compile; the hook and the gauntlet both call it. lint-staged autofixes are safe-only; never add an `--unsafe` flag.
- **Lockfile sync is four thin hooks around one script.** `post-merge`, `post-rewrite`, `post-checkout`, and `post-commit` each compute a rev range and call `scripts/install-changed-lockfiles.sh`, which runs `npm install` in every workspace whose `package-lock.json` changed in that range. Each hook's range is chosen from how that git operation moves HEAD and is not interchangeable: `HEAD@{1}` for a merge, `ORIG_HEAD` for a rebase (HEAD moves once per replayed commit), `$1..$2` for a branch checkout, `HEAD^1` for a conflicted merge finished by `git commit` (gated on `HEAD^2` existing). `post-checkout` skips while a rebase is in progress so `git pull --rebase` installs once, not twice.
- **The sync is fail-open; the gates are fail-closed.** The sync never blocks a git operation: unresolvable revs exit 0, a failed install warns on stderr, and a lockfile that `npm install` rewrote is reported (review and commit it deliberately). `pre-commit` and `check:hooks` refuse with a message naming what is wrong.
- **Not covered by the sync, deliberately:** `git reset --hard`, a conflicted `cherry-pick`/`revert` (one-parent commit), `commit --amend`, and an ordinary commit that edits a lockfile. Anything that provisions a tree by means other than a hook-firing git operation must run the install itself; the hook detects a lockfile _changing_, not an installed tree that disagrees with it.
- **Every hook body runs under `sh -e`** (husky's dispatcher), so guard anything that may legitimately fail with `|| exit 0`. A misnamed hook file is a hook that never runs and never says so; `check:hooks` catches a missing dispatcher, not a misnamed body.
- **Shell tests live in `scripts/tests/*.test.sh`** and are discovered by `find`, so a new suite cannot be added and silently never run. Each suite scrubs git's exported `GIT_*` pointers first, sandboxes in `mktemp -d`, stubs `npm` on `PATH` with a stub that drains stdin, and carries a positive control beside every "expect zero" assertion.

**Git history & merging:**

- **Never squash commits or otherwise rewrite git history unless explicitly authorized.** That includes squash-merges, interactive-rebase squashing, `git commit --amend` on already-pushed commits, and force-pushing. Rewriting history is dangerous — it discards commits and context and can clobber work.
- When integrating a branch, **prefer a normal merge commit** (over squash- or rebase-merge) whenever possible.

## LLM Model Selection

When writing or reviewing code that calls an LLM — or when the user asks which model to use — never default to a single "best practice" model without thinking through the specific usage. The right model/reasoning combo depends on several factors, and the optimal choice is often not the obvious default. Always **present the user with options and tradeoffs** rather than silently picking one.

**Factors to reason through:**

- **Who uses this call?** A background batch job (no human waiting) tolerates higher latency and can use a larger model for accuracy. A customer-facing feature needs fast time-to-first-token and should prefer a lighter model or adaptive reasoning.
- **Latency requirements.** Streaming to a live user? Minimize TTFT — prefer smaller models, `effort: 'low'` or `'medium'`, and skip thinking on simple paths (`thinking: { type: 'adaptive' }`). Asynchronous enrichment pipeline? Latency doesn't matter; accuracy does.
- **Accuracy and reasoning needs.** Simple classification, extraction, or slot-filling → smaller/faster model (e.g. Haiku). Multi-step reasoning, SQL generation, complex analysis → a reasoning-capable model at the appropriate effort level. Don't pay for reasoning on calls that don't need it; don't skimp on it for calls that do.
- **Tool use.** Heavy agentic tool loops (multiple round-trips, SQL generation, web search) benefit from reasoning. Single-tool structured-extraction calls usually don't.
- **Context length.** Does the call need long-context (large documents, long conversation history)? Some models handle this better or more cheaply than others.
- **Cost.** A call made once per user action has a different cost profile than one made per row in a 100k-row enrichment job. Match the model tier to the volume and business value.

**Reasoning / thinking / effort knobs (Anthropic):**

| Setting                          | When to use                                                                            |
| -------------------------------- | -------------------------------------------------------------------------------------- |
| No thinking (default)            | Fast, simple calls — classification, slot-fill, short generation                       |
| `thinking: { type: 'adaptive' }` | Mixed workloads — simple queries skip thinking, hard ones use it; minimal TTFT penalty |
| `thinking: { type: 'enabled' }`  | Always reason — analytics, complex SQL, multi-hop questions                            |
| `effort: 'low'`                  | Latency-critical, low-complexity                                                       |
| `effort: 'medium'`               | Balanced; good default for interactive tool-use calls                                  |
| `effort: 'high'` (default)       | High-stakes, slow-path, or batch accuracy work                                         |

Present these options explicitly when a model choice is ambiguous. The best combo is sometimes counterintuitive — e.g., a smaller model with full thinking can outperform a larger model without it on reasoning tasks, at lower cost and similar latency.

### Routing: OpenRouter by Default, Vercel AI Gateway as the Alternative

**Every LLM call goes through a routing gateway rather than a provider SDK pointed at one vendor, and the default is OpenRouter.** Vercel AI Gateway is the sanctioned alternative. A gateway is what makes the selection rules above actionable: one credential and one billing/usage surface across providers, a model swap that is a string change rather than an integration, and failover when an upstream is rate-limiting or down.

- **Prefer OpenRouter unless the repo has a stated reason not to.** A broad model catalog behind one OpenAI-compatible surface (`/api/v1/chat/completions`), so it needs no bespoke client; with the Vercel AI SDK, use the `@openrouter/ai-sdk-provider` package in place of `@ai-sdk/anthropic`. Choose Vercel AI Gateway when the app already runs on Vercel and wants that integration — and write the reason into this file, or the next agent "fixes" it back.
- **The shipped scaffold already follows this.** `langfuse.traceExample` in `src/trpc/routers/langfuse.ts` builds its model with `createOpenRouter` from `@openrouter/ai-sdk-provider` (the 2.x line, which peers on `ai@6`; 3.x needs `ai@7`) and one `OPENROUTER_API_KEY`. Copy that call site for new LLM calls; no vendor SDK (`@ai-sdk/anthropic`, `@ai-sdk/openai`) is installed, and adding one needs the justification above.
- **Set the data-retention policy before the first real request; the default is not fail-closed.** OpenRouter's account privacy settings decide whether traffic may route to providers that train on it — separate settings for paid and free models, plus per-request data-policy filters to narrow further — and that setting governs the upstreams, not what the gateway itself keeps. A gateway sees every prompt and completion, so its retention and logging get the same single project-wide treatment as Langfuse's (see **Langfuse (Tracing Yes, Prompts No)**), and the decision belongs in this file rather than in one person's dashboard.
- **A gateway key is account-scoped: it reaches every provider that account can reach, and all of its credit.** That is the **Security Posture** blast-radius rule rather than a new one — scope it with whatever the gateway actually offers (a dedicated account, per-key credit limits, a separate key per project), never one shared key pasted into every repo's env.
- **Going direct to a provider needs a justification in the diff**, not silence. The legitimate cases are a provider-specific capability the gateway does not expose, and a hard requirement that traffic not transit a third party. Otherwise the direct SDK is the thing this rule exists to prevent.
- **A gateway is a routing layer, not a reason to stop pinning the model.** Pin explicit model ids per call site; a floating alias silently changes behavior, and a model swap is a behavior change to diff over real inputs before it ships.
- **Prompt caching survives a gateway only when the prefix is byte-stable AND requests keep landing on the same upstream.** Both gateways route one model across several upstream providers and regions, and a route change is a full cache miss — this is what "Pin conversations to one provider/region" under **Aggressive Prompt Caching** is for. Neither gateway is hands-off about it; **Provider notes** below has what each one needs. Confirm from the returned usage rather than assuming either did it.
- **The gateway also moves where the numbers live.** Usage comes back in the gateway's shape rather than the upstream provider's, and a provider's token-counting endpoint may not be exposed at all — OpenRouter has no `count_tokens` equivalent, so token counts and cost come from `/api/v1/generation?id=<id>` after the request completes (real counts, not an estimate).
- **Gateway model catalogs, ids, pricing, and caching support move fast** — read the current docs when wiring or reviewing one rather than working from memory.

## LLM Calls (Prompt Caching & Observability)

### Aggressive Prompt Caching + Cache Pre-Warming

For **all LLM calls, regardless of provider**, always look for opportunities to implement aggressive prompt caching and to pre-warm the cache so it is always hot when real requests arrive. Prompt caching is a near-free win: cached input tokens are ~50–90% cheaper depending on provider, and time-to-first-token drops by up to ~80%. Pre-warming ensures bursty or low-traffic workloads don't pay cold-cache prices — the warmer keeps the cache alive between real requests. Whenever you write or review code that calls an LLM, check whether the prompt is structured to maximize cache hits and whether a background pre-warmer is warranted — and add both if not. Provider caching APIs, pricing, and TTLs evolve — search the internet for the provider's current prompt-caching docs and best practices when implementing or reviewing (the provider notes below are a snapshot, not the source of truth).

#### The one invariant: caching is an exact prefix match

Every provider's cache keys on the exact bytes of the prompt prefix. A single byte change anywhere in the prefix invalidates everything after it. So **order prompt content by stability**:

1. **Static first**: tool definitions, system prompt, few-shot examples, large reference documents — frozen, byte-identical across requests.
2. **Per-session next**: conversation history (append-only — never rewrite earlier turns).
3. **Volatile last**: the user's current question, timestamps, request-specific data — after the last cache boundary.

#### Rules

- **Freeze the system prompt.** Never interpolate timestamps, dates, UUIDs, request IDs, or per-user values into the system prompt or tool definitions — that invalidates the cache on every request. Inject dynamic context late in the message list instead.
- **Serialize deterministically.** Sort JSON keys, keep tool lists in a stable order, and never iterate unordered sets/maps when building the prompt. Don't add/remove/reorder tools or switch models mid-conversation — both force a full cache rebuild.
- **Multi-turn conversations**: append new turns to the end and resend the identical history so each request reuses the prior conversation's cached prefix.
- **Verify with usage metrics, don't assume.** Check the response usage fields: Anthropic `usage.cache_read_input_tokens`, OpenAI `usage.prompt_tokens_details.cached_tokens`. Zero across repeated similar requests means a silent invalidator (timestamp in the prompt, unsorted JSON, varying tool set) — diff the rendered prompt bytes between two requests to find it.
- **Mind minimum sizes and TTLs.** Caches require a minimum prefix (~1024+ tokens, model-dependent) and expire after minutes of inactivity (Anthropic 5 min default / 1 h option; OpenAI ~5–10 min). For bursty traffic, consider a longer TTL or pre-warming; for continuous traffic, regular requests keep the cache warm.
- **Treat cache hit rate as a first-class production metric.** Compute it as `cache_read / (input + cache_creation + cache_read)` and alert on drops — a deploy that reorders JSON keys or adds a timestamp shows up as a hit-rate drop / cost spike before anyone notices.
- **Warm sequentially before fanning out.** A cache entry is only readable once the first response begins streaming — N parallel identical requests all pay full write price. Send one request, await the first streamed token, then fire the remaining N−1. (Anthropic also supports explicit pre-warming via a `max_tokens: 0` request.)
- **Pin conversations to one provider/region.** When routing through a gateway or load balancer, identical prefixes must land on the same backend; provider failover mid-conversation is a full cache miss (same as a model switch).
- **RAG placement**: cache only the shared retrieved corpus (documents that repeat across requests); per-query retrievals go after the last breakpoint. Put breakpoints at the end of the shared portion — never on the varying suffix, or every request writes a cache that nothing ever reads.

#### Provider notes

- **Anthropic**: explicit — add `cache_control: {type: "ephemeral"}` breakpoints (max 4) at stability boundaries, or pass `cache_control` as a top-level request param to auto-place one on the last cacheable block. Writes cost 1.25× (5 min TTL) / 2× (1 h TTL, GA — breaks even at ≥3 requests vs 2 for 5-min), reads ~0.1×. Each breakpoint looks backward up to ~20 content blocks for the longest cached prefix, so in long agentic turns (many tool_use/tool_result blocks) add an intermediate breakpoint every ~15 blocks. Minimum cacheable prefix is model-dependent (~1024–4096 tokens; below it caching silently no-ops with `cache_creation_input_tokens: 0`). Rate-limit win: on current models, cache reads do NOT count toward input-tokens-per-minute limits. Invalidation is tiered: tool-definition or model changes invalidate everything; system-prompt changes keep the tools cache; `tool_choice`/thinking toggles keep tools+system.
- **OpenAI**: automatic for prompts ≥1024 tokens (no code change), but only pays off when the prefix is byte-stable — structure still matters. Routing hashes the first ~256 tokens; set `prompt_cache_key` (per workload/session, not per request) to steer same-prefix traffic to the same machine, and shard keys beyond ~15 requests/min per prefix. `prompt_cache_retention: "24h"` extends retention on supported models. Caching covers messages, images, tool definitions, and structured-output schemas.
- **Google Gemini**: implicit caching on 2.5+ models, plus an explicit cache API for large shared contexts.
- **Vercel AI SDK**: set breakpoints with `providerOptions: { anthropic: { cacheControl: { type: 'ephemeral' } } }` (camelCase) on a system message (message-array form, not the `system:` string), on a message part, or inside the **last** `tool({...})` definition (tools render first; one breakpoint covers all preceding tools). Add `ttl: '1h'` for the long TTL (the SDK sets the beta header). Read cache usage from `result.providerMetadata?.anthropic` (`cacheReadInputTokens` / `cacheCreationInputTokens`) — it is NOT in `result.usage`. Through Vercel AI Gateway, `providerOptions: { gateway: { caching: 'auto' } }` auto-places a breakpoint for explicit-cache providers; without it, Anthropic-via-gateway gets no caching at all.
- **OpenRouter** (the default route — see **Routing** above): two ways to cache against Anthropic upstreams — a single top-level `cache_control`, which auto-places the breakpoint on the last cacheable block and advances it as the conversation grows, or up to four explicit per-block breakpoints for fine control. Cached tokens report in the OpenAI shape (`usage.prompt_tokens_details.cached_tokens`, alongside `cache_write_tokens`), **not** Anthropic's `cache_read_input_tokens` — an agent checking the upstream provider's field name reads zero and concludes caching is broken. Sticky routing keeps a conversation on whichever upstream holds the cache, but only while that provider's cache-read price beats its normal prompt price, and it lapses after 10 minutes of inactivity; pass a `session_id` (top-level body field or `x-session-id` header, ≤256 characters) to pin the key explicitly instead of leaving it derived from a message hash.
- Other gateways and hosted providers (Bedrock, Vertex, etc.) generally proxy the underlying provider's caching — same prefix-stability rules apply.

### Langfuse (Tracing Yes, Prompts No)

When Langfuse is configured in this repo, then:

- **All LLM calls must be recorded through Langfuse tracing and sessions.** Every call site that hits an LLM should be wrapped in the tracing setup (observations/spans grouped by session ID — see the Langfuse Integration section below) so cost, latency, and behavior are observable per conversation.
- **Do not store LLM prompts in Langfuse** (no `getPrompt()` / Langfuse prompt management). Prompts live **in the codebase** as the single source of truth — so they're version-controlled alongside the code that uses them, and so terminal agents like Claude Code can easily read them as valuable context.
- **Track cache hit rate in Langfuse.** Report cache tokens as distinct usage types on generation observations so Langfuse prices them correctly and hit rate is chartable. Through OpenRouter they arrive as `result.usage.cachedInputTokens` (from `prompt_tokens_details.cached_tokens`), never under the upstream vendor's field names. With OTel-based ingestion, verify cache tokens aren't double-counted (some genai conventions fold cache reads into `usage.input`). AI SDK `experimental_telemetry` spans carry provider metadata through automatically.

### Langfuse Integration (Optional — Setup & AI SDK Patterns)

[Langfuse](https://langfuse.com/) provides observability for LLM applications. Per the policy above, this template uses it for **tracing and session tracking only** — prompts live in the codebase at `apps/api/src/prompts/` (the `getPrompt` helper there handles `{{variable}}` interpolation), never in Langfuse prompt management.

**Setup:**

1. Get keys from [cloud.langfuse.com/project/\_/settings](https://cloud.langfuse.com/project/_/settings)
2. Set in `.env`:
   ```bash
   LANGFUSE_PUBLIC_KEY=your-key
   LANGFUSE_SECRET_KEY=your-key
   LANGFUSE_BASE_URL=https://cloud.langfuse.com  # optional
   ```
3. Langfuse is automatically initialized on server startup
4. Health check at `/health` includes Langfuse status

**Features:**

- `src/prompts/index.ts` — LLM prompts (codebase source of truth) with a registry, `{{variable}}` interpolation, and a typed `getPrompt`
- `src/services/langfuse.ts` — Langfuse client init for tracing/sessions; gracefully degrades if keys are missing
- `src/services/telemetry.ts` — OpenTelemetry SDK with LangfuseSpanProcessor (auto-captures AI SDK spans)
- `langfuse.test` (tRPC query) — Verify Langfuse connectivity
- `langfuse.getPrompt` (tRPC query) — Fetch and render a codebase prompt with variable substitution; works whether or not Langfuse is configured
- `langfuse.traceExample` (tRPC mutation) — Runnable scaffold: Vercel AI SDK through OpenRouter (Claude Haiku 4.5 by catalog id) + tools + tracing + sessions + OpenRouter's request-level prompt-caching breakpoint to copy

**AI SDK + Langfuse tracing pattern:**

The template uses [Vercel AI SDK](https://sdk.vercel.ai/) (`ai`) with the [OpenRouter provider](https://openrouter.ai/docs/guides/community/vercel-ai-sdk) (`@openrouter/ai-sdk-provider`) for LLM calls, so any model in OpenRouter's catalog is one string away and no vendor SDK is installed. Both `generateText` and `streamText` are current, non-deprecated APIs:

- `generateText` — non-interactive/agent use; waits for full completion before returning
- `streamText` — interactive/chat use; streams tokens to the client in real time

Tracing flows through OpenTelemetry automatically via `experimental_telemetry` — no manual span creation needed for token counts or model metadata.

**Full pattern with tool call (from `src/trpc/routers/langfuse.ts`):**

```typescript
import { generateText, tool, stepCountIs } from "ai";
import { createOpenRouter } from "@openrouter/ai-sdk-provider";
import { z } from "zod";
import { startActiveObservation, propagateAttributes } from "@langfuse/tracing";

// Pin the model per call site by OpenRouter catalog id (https://openrouter.ai/models).
const MODEL = "anthropic/claude-haiku-4.5";

// Define a tool — replace execute() with a real API call
const getCurrentWeather = tool({
  description: "Get the current weather for a city.",
  inputSchema: z.object({
    city: z.string().describe("The city to get weather for"),
  }),
  execute: async ({ city }) => ({ city, temperature: 68, condition: "Sunny" }),
});

// Every call gets a Langfuse session — fall back to a generated ID when the
// client doesn't supply one, so no LLM call is session-less
const effectiveSessionId = sessionId ? String(sessionId) : `anon-${crypto.randomUUID()}`;
const traceAttrs = { sessionId: effectiveSessionId };

const openrouter = createOpenRouter({ apiKey: env.OPENROUTER_API_KEY });
const model = openrouter(MODEL, {
  usage: { include: true }, // real token counts + cost on providerMetadata.openrouter.usage
  extraBody: { session_id: effectiveSessionId }, // pins OpenRouter's sticky routing to the cached upstream
});

await startActiveObservation("my-llm-call", async (span) => {
  span.update({ input: { prompt } }); // annotate the Langfuse observation

  await propagateAttributes(traceAttrs, async () => {
    const result = await generateText({
      model,
      prompt,
      tools: { getCurrentWeather },
      // stopWhen enables multi-step: model calls tool → gets result → generates final text
      stopWhen: stepCountIs(3),
      // Request-level breakpoint: becomes OpenRouter's top-level cache_control, which places
      // the breakpoint on the last cacheable block and advances it as the conversation grows.
      // Engages once the prefix exceeds the model's minimum cacheable size.
      providerOptions: { openrouter: { cacheControl: { type: "ephemeral" } } },
      experimental_telemetry: {
        isEnabled: true,
        functionId: "my-llm-call", // label shown in Langfuse
        metadata: { route: "/my-route" },
      },
    });

    generatedText = result.text;
    // result.usage: { inputTokens, outputTokens, totalTokens, cachedInputTokens }
    // result.providerMetadata?.openrouter?.usage: { cost, totalTokens, ... } (OpenRouter's own accounting)
    // result.steps[].toolResults: [{ toolName, input, output }]
  });

  span.update({ output: { text: generatedText } });
});
```

**Key concepts:**

- `tool({ description, inputSchema, execute })` — AI SDK v6 tool definition. Use `inputSchema` (Zod), NOT `parameters`. The `execute` function receives validated input and returns a result the model can use.
- `stopWhen: stepCountIs(N)` — enables multi-step agentic loops: model calls tool → SDK executes it → result fed back → model continues. Caps at N steps.
- `startActiveObservation(name, fn)` — wraps the async function in a Langfuse observation. Call `span.update({ input, output })` to annotate. Ends automatically when `fn` resolves.
- `propagateAttributes({ sessionId })` — binds a session ID to all child spans via Node.js async context. Groups multiple requests into one session in the Langfuse UI.
- `experimental_telemetry` — enables AI SDK's built-in OTel instrumentation. `LangfuseSpanProcessor` in `telemetry.ts` captures these spans automatically.

**Switching models:**

```typescript
// Any catalog id works with the same provider and the same key — no new SDK, no new env var.
// Look ids up at https://openrouter.ai/models (or GET https://openrouter.ai/api/v1/models).
openrouter("anthropic/claude-haiku-4.5"); // fastest, cheapest Claude
openrouter("anthropic/claude-sonnet-4.6"); // balanced Claude
openrouter("openai/gpt-5-mini"); // an OpenAI model, same call site
```

A model swap is a behavior change: diff outputs over real inputs before shipping it, and pin the id rather than a floating alias.

**Streaming (for real-time chat):**

```typescript
import { streamText } from "ai";

const result = streamText({
  model,
  prompt,
  tools: { getCurrentWeather },
  stopWhen: stepCountIs(3),
  experimental_telemetry: { isEnabled: true, functionId: "my-stream" },
});

// Pipe to Express response (SSE):
result.pipeTextStreamToResponse(res);
```

**Test the scaffold:**

```bash
# Requires OPENROUTER_API_KEY in apps/api/.env (set OPENROUTER_BASE_URL only to point at a proxy or a local stand-in)
curl -X POST http://localhost:8000/trpc/langfuse.traceExample \
  -H "Content-Type: application/json" \
  -H "x-trpc-source: curl" \
  -d '{"prompt": "What'\''s the weather in Paris?", "sessionId": "my-session-123"}'
# Returns (in the tRPC envelope {"result":{"data":{...}}}):
#   { text, usage, toolCalls: [{ tool, input, output }], sessionId, langfuseTraced }
```

All Langfuse features are **optional** and gracefully degrade if not configured.

## Common Pitfalls to Avoid

### General

- ❌ Don't assume code exists - always verify by reading files
- ❌ Don't skip testing after changes
- ❌ Don't ignore type errors
- ❌ Don't make large, multi-purpose commits
- ❌ Don't commit broken builds
- ❌ Don't duplicate code - create reusable utilities instead

### JavaScript/TypeScript

- ❌ Don't use outdated syntax (var, function declarations, etc.)
- ❌ Don't ignore TypeScript errors or use `any` without justification
- ❌ Don't forget to handle loading and error states
- ❌ Don't forget cleanup in useEffect hooks
- ❌ Don't mutate state directly (use immutable updates)

### Node.js/Express

- ❌ Don't forget `.js` extensions in ESM imports from TypeScript files
- ❌ Don't use `process.env` directly; use `getEnvironment()` instead
- ❌ Don't mix Zod validation with TypeScript-only types
- ❌ Don't ignore Zod validation errors
- ❌ Don't forget to close database/Redis connections on shutdown
- ❌ Don't use `http-errors` in tRPC procedures — use `TRPCError` with the correct code
- ❌ Don't forget to rebuild the API (`npm run build:api`) after changing tRPC routers — the web typecheck depends on emitted declarations
- ❌ Don't create a worktree with a bare `git worktree add` — use `npm run worktree:new`, or git runs no hooks there until a root `npm install`
- ❌ Don't read "Cannot find module ..." in pre-commit as a bug in your diff — it is usually a stale `node_modules`; if a hook did not reinstall, run `npm ci` in that workspace

## Deployment

### Vercel (Web App)

The `vercel.json` at the root is simplified:

- Framework: Next.js (auto-detected)
- Deploys on pushes to `main` and `develop`

**Setup:**

1. Connect repository to Vercel
2. Vercel auto-detects `vercel.json`
3. **After deploying, manually set root directory to `apps/web` in Vercel dashboard** (Settings → General → Root Directory)
4. Set environment variables (`NEXT_PUBLIC_API_URL`, etc.)
5. Deploy

### Railway (Backend API)

The Railway environment is declared as Infrastructure as Code in `.railway/railway.ts` and managed with `railway config plan` / `railway config apply`. Config as Code (`railway.json` / `railway.toml`) is deprecated and Railway stops reading it on 2026-12-01. Never add one back: a service managed by both is refused by `railway config plan`.

- `.railway/railway.ts` - The whole environment: the `API` service (`build: { builder: 'DOCKERFILE', dockerfilePath: 'apps/api/Dockerfile' }`, `start`, `deploy.restartPolicyType`/`restartPolicyMaxRetries`), `redis('Redis')` wired into `REDIS_URL`, and the `Keep-Alive` function (`fn(...)` with `deploy.cronSchedule`, its script base64-encoded from `apps/cron/src/keep-alive.ts` into the start command). Every secret is `preserve()`; never write a value into this file
- `.railway/tsconfig.json` + `npm run typecheck:railway` - Typechecks the file against the `railway` SDK. **This is the only check that catches an unknown key**: `railway config plan` forwards a misspelled key to Railway unchanged (verified: `dockerfilePathh` planned as a new setting), so run the typecheck before every plan
- `apps/api/Dockerfile` - Build configuration (`node:24-alpine`, `npm ci` + `npm run build`); requires repo-root build context because it copies `apps/shared/` alongside `apps/api/`, so the service keeps `rootDirectory: '/'`
- `apps/api/package.json` and `package-lock.json` - Node.js dependencies for this service

**Rules for editing `.railway/railway.ts`:**

- **Omit means delete.** `apply` removes any service, database, volume, or variable that exists in the environment but is not declared. Declare everything, and read the plan's destroy lines before confirming. `railway config pull --force` re-imports the live environment when the file has drifted
- **Agents plan, Bryan applies.** `railway config plan` is read-only and allowed; `apply`, `init`, `pull`, and `migrate` change Railway or overwrite the file and are denied to agents by `guard-railway-readonly.sh`. From an unlinked clone, plan non-interactively with `RAILWAY_PROJECT_ID=<id> RAILWAY_ENVIRONMENT_ID=<id> railway config plan </dev/null` (the `config` subcommands accept no `-p`/`-e` flags)
- **The SDK checks the CLI version by running the executable named in the `$_` env var.** A wrapper that execs the CLI (`perl -e 'exec ...'`, some `timeout` shims) leaves `$_` pointing at the wrapper and the plan fails with "requires Railway CLI 5.42.1 or newer" even on a current CLI; run `railway` directly
- **Declare `networking.privateNetworkEndpoint`** for each service (`api`, `keep-alive`). Without it the plan reports a networking change on every run. Generated `*.up.railway.app` domains are not managed by the file; custom domains go in `domains: [...]`
- **The file runs under Node with type stripping**, so keep it to erasable syntax (no `enum`, no parameter properties); `erasableSyntaxOnly` in its tsconfig enforces that. Node built-ins and `import.meta.url` work
- Keys and enum values are the Railway service-config shape (`builder: 'DOCKERFILE'`, `restartPolicyType: 'ON_FAILURE'`); confirm any new one in `node_modules/railway/dist/index-*.d.ts` or the [DSL reference](https://docs.railway.com/infrastructure-as-code/reference) rather than from memory

**Setup for a new deployment:**

1. Create the Railway project, `railway login`, `railway link` in the repo root
2. Update the `REPO` constant and project name in `.railway/railway.ts`
3. `railway config plan`, then `railway config apply` (creates API, Redis, and Keep-Alive)
4. Set secret values (SUPABASE_URL, SUPABASE_SECRET_KEY, CORS_ORIGINS) in the Railway dashboard

**Why per-service configuration:**

- Each service has its own dependencies and configuration
- Services can be deployed and scaled independently
- Easy to add new services without affecting existing ones
- Clear separation of concerns

### Adding More Services

To add additional backend services:

1. Create new service directory under `apps/` (e.g., `apps/worker/`)
2. Add service-specific configuration files:
   - `Dockerfile` - Build config (Node.js 24+; copy `apps/shared/` too if the service uses shared types)
   - `package.json` and `package-lock.json` - Dependencies
   - `.env.example` - Environment template
3. Declare it in `.railway/railway.ts` with the same `github(REPO, ...)` source, `build: { builder: 'DOCKERFILE', dockerfilePath: 'apps/worker/Dockerfile' }`, `start`, `networking.privateNetworkEndpoint`, and its variables, then add it to the project's `resources`
4. `npm run typecheck:railway`, `railway config plan`, then `railway config apply`
5. Deploys independently on every push

**Example multi-service structure:**

```
apps/
├── web/              # Next.js frontend
│   ├── package.json
│   └── ...
├── api/              # Express + tRPC API
│   ├── Dockerfile
│   ├── package.json
│   └── ...
├── worker/           # Background jobs (Node.js + Bull)
│   ├── Dockerfile
│   ├── package.json
│   └── ...
└── websocket/        # WebSocket server (Node.js)
    ├── Dockerfile
    ├── package.json
    └── ...
```

## Project-Specific Patterns

### Environment Variables

**Frontend** (`apps/web/.env.local`):

```bash
NEXT_PUBLIC_APP_URL=http://localhost:3000
NEXT_PUBLIC_API_URL=http://localhost:8000

# Supabase (Required for auth)
NEXT_PUBLIC_SUPABASE_URL=https://your-project.supabase.co
NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY=sb_publishable_xxxxxxxxxxxxx
SUPABASE_SECRET_KEY=sb_secret_xxxxxxxxxxxxx

# Optional — for cross-subdomain cookies (e.g. .myapp.com)
# SUPABASE_COOKIE_DOMAIN=

# Invitation Gating (Optional — comma-separated emails. Empty = open signup)
# INVITED_EMAILS=alice@example.com,bob@example.com

# Admin Email Domain (Optional — emails @this-domain bypass invite check)
# ADMIN_EMAIL_DOMAIN=mycompany.com

# Azure OAuth Client ID (Optional — for Microsoft domain verification via .well-known endpoint)
# AZURE_OAUTH_CLIENT_ID=your-azure-app-client-id
```

**Backend** (`apps/api/.env`):

```bash
PORT=8000
NODE_ENV=development
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_SECRET_KEY=sb_secret_xxxxxxxxxxxxx
REDIS_URL=redis://localhost:6379
CORS_ORIGINS=http://localhost:3000,http://localhost:3001
```

**Supabase Keys:**

- `SUPABASE_SECRET_KEY` (starts with `sb_secret_`): Server-side only. Use in Express backend for database operations, auth administration, and other privileged actions. **Keep this secret!**
- `SUPABASE_PUBLISHABLE_KEY` (starts with `sb_publishable_`): Safe for client-side. Use in browser/frontend if calling Supabase directly (optional).

### API Integration Pattern

**Frontend (tRPC query hook):**

```typescript
'use client';

import { useQuery } from '@tanstack/react-query';
import { useTRPC } from '@/lib/trpc';

const MyComponent = () => {
  const trpc = useTRPC();
  const { data, isLoading, error } = useQuery(trpc.health.check.queryOptions());

  if (isLoading) return <p>Loading...</p>;
  if (error) return <p>Error: {error.message}</p>;
  return <p>Status: {data?.status}</p>;
};
```

**Backend (tRPC procedure):**

```typescript
import { z } from "zod";
import { createRouter, publicProcedure } from "@/trpc/init.js";

const UserRequestSchema = z.object({
  name: z.string(),
  email: z.string().email(),
});

const UserResponseSchema = z.object({
  id: z.number(),
  name: z.string(),
  email: z.string().email(),
});

export const userRouter = createRouter({
  create: publicProcedure
    .input(UserRequestSchema)
    .output(UserResponseSchema)
    .mutation(({ input }) => {
      return { id: 1, ...input };
    }),
});
```

### CORS Configuration

CORS is configured in `src/middleware/cors.ts`. The middleware:

- Automatically allows localhost (http://localhost:3000, http://localhost:3001, etc.)
- Reads allowed origins from `CORS_ORIGINS` environment variable (comma-separated)
- Supports wildcard `"*"` for development
- Logs rejected origins for debugging

### Database Integration

**Common patterns:**

- Use Prisma for ORM (has excellent TypeScript support)
- Run migrations via `npx prisma migrate`
- Store connection string in `DATABASE_URL` environment variable
- Use connection pooling for production (Prisma does this automatically)

### SQL Migrations (Supabase)

Migration files live in `apps/shared/supabase/migrations/`.

These rules apply to all **future** migrations. Do not retrofit legacy migration files (any that lack the `.up.sql`/`.down.sql` pattern) to these conventions — leave them as-is.

**Never run migrations programmatically.** The SQL files are documentation only — never execute them against the database (no `psql`, no `supabase db push`, no programmatic execution of any kind). The engineer will manually run the correct migrations as queries in the Supabase web UI (SQL Editor). When planning schema changes, the deliverable is the migration files themselves, not an applied migration.

**Two files per migration: `.up.sql` and `.down.sql`**

- `<name>.up.sql` — applies the migration.
- `<name>.down.sql` — manual rollback. It must restore the database as faithfully as possible to the state before the `.up` was run. Sometimes rollback unavoidably deletes data (e.g., dropping a column the up added) — that's acceptable.
- If the `.up` performs multiple operations in sequence, the `.down` must apply the "undo" operations in **reverse order** so the rollback unwinds cleanly.
- When a migration file is created, edited, or deleted, keep its `.up.sql`/`.down.sql` pair in sync.
- Every `.down.sql` file (migrations and seeds alike) must start with a comment at the top of the file stating that it must be kept in sync with its corresponding `.up.sql` file.

**Idempotency** — all migration SQL must be safe to run more than once:

- `CREATE TABLE IF NOT EXISTS ...`
- `ALTER TABLE ... ADD COLUMN IF NOT EXISTS ...`
- `CREATE INDEX IF NOT EXISTS ...`
- `DROP ... IF EXISTS ...`
- `CREATE OR REPLACE FUNCTION ...`
- For things without `IF NOT EXISTS` support (policies, constraints, types, triggers): `DROP ... IF EXISTS` first, or wrap in a `DO $$ ... $$` block that checks `pg_policies` / `pg_constraint` / `pg_type` before creating.

**Fail-early guards** — each `.up.sql` must begin with guard(s) that fail early if existing data would guarantee the migration fails partway through, e.g. violation of an invariant being introduced (unique constraint, foreign key reference, NOT NULL):

```sql
-- Guard: adding UNIQUE(email) — fail early if duplicates exist
do $$
begin
  if exists (
    select 1 from public.users group by email having count(*) > 1
  ) then
    raise exception 'Migration aborted: duplicate emails in public.users would violate the new unique constraint';
  end if;
end $$;
```

**Explicit GRANTs (required — Supabase enforces this)**

Supabase no longer auto-grants table privileges: new tables in projects created after **May 30, 2026** (and, from **Oct 30, 2026**, new tables in existing projects) receive **no grants** to `anon`, `authenticated`, or `service_role`. Without an explicit `GRANT`, PostgREST/supabase-js returns `permission denied for table ...` **before RLS policies are even evaluated**. Note that `service_role` bypasses RLS but still requires GRANTs.

Whenever a migration creates, edits, or deletes a table (or changes its access patterns), the same migration must include the appropriate `GRANT` and row-level security (RLS) statements, if applicable. Reason about who should have which access — `anon`, `authenticated`, `service_role` — and which operations (SELECT/INSERT/UPDATE/DELETE) each needs. Treat **grant + enable RLS + policies as a single unit**:

```sql
-- Grants: scope to the roles/operations this table actually needs
grant select on public.your_table to anon;                                  -- only if publicly readable
grant select, insert, update, delete on public.your_table to authenticated; -- per access needs
grant select, insert, update, delete on public.your_table to service_role;

-- If the table has identity/serial columns:
grant usage, select on all sequences in schema public to authenticated, service_role;

-- RLS: grants control whether a role can touch the table at all;
-- RLS controls which rows it can see/modify
alter table public.your_table enable row level security;

drop policy if exists "users can read their own rows" on public.your_table;
create policy "users can read their own rows"
  on public.your_table
  for select
  to authenticated
  using (auth.uid() = user_id);
```

The corresponding `.down.sql` must `REVOKE`/`DROP POLICY` (in reverse order) as part of its rollback.

### Supabase Types

Generate TypeScript types from your Supabase schema through the committed wrapper, never the bare generator. A bare `npx supabase gen types … > types.ts` truncates the committed file before the generator runs, so a failed login or a wrong project id leaves it empty; the wrapper generates to a temp file, refuses output that is not a types module, and only then moves it into place. It reads the project id from `SUPABASE_URL` in `apps/api/.env` and writes `apps/shared/supabase/types.ts`; `--local` generates from a running local Supabase stack instead:

```bash
bash scripts/gen-supabase-types.sh            # project in apps/api/.env
bash scripts/gen-supabase-types.sh --local    # local Supabase stack
```

`types.ts` is generated only and exempt from Biome (the `**/supabase/types.ts` override), so the stored form is the generator's own output and a regeneration diff contains only schema changes. Read every removed line of that diff; it is the only place a drifted schema is visible. Never hand-edit the file: the next regeneration discards the edit. Where the generated type is too loose (a pgvector column comes out as `string | null` and the app wants `number[]`), narrow it in hand-written code that imports from `types.ts`.

The generated `Database` type is used in `src/services/supabase.ts` for full type safety:

```typescript
import type { Database } from "@shared/supabase/types.js";
const supabaseClient: SupabaseClient<Database> = ...
```

### Supabase API Keys

Supabase uses two types of API keys (new format as of 2025):

**SUPABASE_SECRET_KEY** (`sb_secret_*`):

- Server-side only (Express backend, Edge Functions, etc.)
- Has elevated permissions for database operations, user management, auth administration
- **Must be kept secret** — never expose in frontend code or public URLs
- Used in `src/services/supabase.ts` to initialize the server client
- Example: `sb_secret_xxxxxxxxxxxxx`

**SUPABASE_PUBLISHABLE_KEY** (`sb_publishable_*`):

- Safe for client-side (browsers, mobile apps)
- Has limited permissions matching your Row Level Security (RLS) policies
- Can be exposed in frontend code (use `NEXT_PUBLIC_` prefix in Next.js)
- Required for Supabase Auth (browser client uses it for login, signup, OAuth, and session management)
- Example: `sb_publishable_xxxxxxxxxxxxx`

**Migration Note:**
Supabase is migrating away from legacy JWT-based keys (old `anon` and `service_role` keys). The new key format started as opt-in in Q1 2025, with full enforcement for new projects starting November 1, 2025. Projects created before then can continue using legacy keys until that date.

## Verification Checklist

Before considering any task complete:

### Code Quality

- [ ] Code verified by reading actual files (not assumed)
- [ ] No hallucinated functions, imports, or APIs
- [ ] Code follows style guidelines (arrow functions, TypeScript types, etc.)
- [ ] Types properly defined (TypeScript interfaces)
- [ ] No unused imports or variables
- [ ] Error cases handled appropriately

### Testing

- [ ] Change tested in running application
- [ ] Functionality confirmed to work as expected
- [ ] No console errors or warnings when testing
- [ ] Build passes successfully (frontend and/or backend)
- [ ] All type errors resolved (TypeScript)
- [ ] No regressions in existing functionality

### Documentation

- [ ] Documentation updated if behavior or APIs changed
- [ ] Code comments added for complex logic
- [ ] README.md updated if user-facing changes were made

### Deployment Readiness

- [ ] No secrets or credentials in code
- [ ] Environment variables properly configured
- [ ] `package.json` and `package-lock.json` updated (if Node.js)

## Agent Session Logging

This project uses [entire.io](https://entire.io/) to log coding agent (Claude Code, etc.) prompts and responses. The `.entire/` directory at the repo root stores the configuration:

- **`.entire/settings.json`** — committed; controls logging strategy (`"manual-commit"`) and telemetry (`false`)
- **`.entire/logs/`**, **`.entire/tmp/`**, **`.entire/metadata/`** — gitignored internally by `.entire/.gitignore`

You do not need to interact with this directory. It runs passively in the background during Claude Code sessions.

## Agent Collaboration

When multiple agents or sessions work on this project:

1. **Always read on startup:**
   - README.md for project overview and setup
   - CLAUDE.md (this file) for development guidelines

2. **Before starting work:**
   - Check `git status` to see current state
   - Review any existing todo lists
   - Search for existing patterns before creating new ones
   - Never assume what other agents have done - verify by reading files

3. **During work:**
   - Use TodoWrite to track progress on multi-step tasks
   - Test after each change, not in batches
   - Mark todos as completed immediately after finishing
   - Communicate clearly about what's being worked on

4. **After completing work:**
   - Update documentation if needed
   - Clear completed todos or clean up todo list
   - Don't leave work in an incomplete state

5. **Never hallucinate:**
   - Don't assume files exist - use Read tool to verify
   - Don't guess at function signatures - search and read
   - Don't invent APIs or configuration options
   - Always verify before acting

## Template Customization

When using this template for a new project:

### Initial Setup

1. Clone the template repository
2. Update `README.md` with your project name and description
3. Update this file (CLAUDE.md) "Project Overview" section with project-specific context
4. Initialize new git repository (or update remote)

### Project-Specific Configuration

1. Add project-specific environment variables to `.env.example` files
2. Configure CORS with your actual frontend URL in `apps/api/src/middleware/cors.ts`
3. Set up database schema (if using Supabase or other database)
4. Configure Supabase Auth providers (email, Google, Microsoft are built in — see README)
5. Customize API routes for your specific use case

### Documentation Updates

1. Document project-specific patterns in this file (CLAUDE.md)
2. Update README.md with project-specific setup instructions
3. Add project-specific testing instructions

### Deployment

1. Connect repository to Vercel and Railway
2. Set up environment variables in deployment dashboards
3. Configure custom domains if needed
4. Set up monitoring/logging services if needed
5. Test deployments thoroughly before going live

## Future Enhancements

Common features to add based on project needs:

- State management (Zustand, Redux)
- Real-time features (WebSockets, Server-Sent Events)
- File uploads (S3, Cloudinary)
- Background jobs (BullMQ)
- Testing (Jest, Playwright)
- CI/CD pipelines
- Docker containerization
- Monitoring and logging (Sentry, LogRocket)
