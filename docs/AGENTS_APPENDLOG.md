# Agent Decision Log (Append-Only)

This file tracks all significant decisions, implementations, and learnings throughout the project lifecycle.

**Format for each entry:**

```markdown
## YYYY-MM-DD HH:MM PT - Entry Title

**Type:** [Decision | Implementation | Documentation | Bug Fix | Refactor]
**Change:** What was changed/decided
**Context:** User prompt or situation that triggered this
**Rationale:** Why this choice was made
**Alternatives Considered:** Other options (if applicable)
**Impact:** Time/complexity/features affected
**Time Spent:** Actual time investment
**Learnings:** Insights or patterns discovered
```

---

## 2025-10-24 14:06 PT - Template Repository Created

**Type:** Implementation
**Change:** Created Next.js + FastAPI template repository structure
**Context:** Initial template setup for rapid project spinning
**Rationale:** Standardize project structure, deployment configs, and best practices across future projects
**Alternatives Considered:**

- Single-service architecture: Rejected because template should support multiple backend services
- Monolithic deployment: Rejected in favor of separate frontend (Vercel) and backend (Railway) deployments
  **Impact:**
- Directory structure: `apps/frontend`, `apps/api`, `docs/`
- Comprehensive .gitignore covering Next.js, FastAPI/Python, and common patterns
- Pre-configured vercel.json for frontend deployment
- Pre-configured railway.json and .railwayignore for backend services
- Documentation: README.md, CLAUDE.md, AGENTS.md, AGENTS_APPENDLOG.md
  **Time Spent:** ~45 minutes
  **Learnings:**
- Template should be generic enough for any project but opinionated enough to provide value
- Deployment configs (vercel.json, railway.json) should be in the right locations for auto-detection
- .railwayignore pattern (excluding all except specific service) prevents deploying entire monorepo
- Comprehensive .gitignore prevents accidentally committing secrets across multiple tech stacks

---

## Template Usage Instructions

When starting a new project with this template:

1. **Clone and Customize**
   - Clone this template repository
   - Update README.md with your project name and description
   - Update CLAUDE.md "Project Overview" section with project-specific context
   - Remove or archive this template section from AGENTS_APPENDLOG.md

2. **Initialize Project**
   - Set up frontend: `cd apps/frontend && npm install`
   - Set up backend: `cd apps/api && python -m venv venv && pip install -r requirements.txt`
   - Copy .env.example files and add your secrets

3. **Start Logging**
   - Continue logging all significant decisions in this file
   - Use the format shown above for consistency
   - Never hallucinate timestamps - use actual current time in PT timezone

4. **Maintain Documentation**
   - Update README.md with user-facing changes
   - Update CLAUDE.md with project-specific patterns
   - Update AGENTS.md with project-specific workflows

---

## 2026-02-23 16:45 PT - Backend Conversion: FastAPI → Express 5 + TypeScript

**Type:** Decision | Implementation
**Change:** Converted backend from Python FastAPI to Node.js Express 5 with TypeScript, unified entire stack to TypeScript
**Context:** Template alignment with production monorepo structure; standardizing on unified TypeScript across frontend and backend
**Rationale:**

- **Unified Stack**: Single language (TypeScript) for entire application reduces context switching and enables code sharing (types, utilities)
- **Developer Velocity**: Consistent tooling, build process, and deployment pattern across frontend and backend
- **Type Safety**: Zod runtime validation + TypeScript compile-time types provide better guarantees than Python Pydantic
- **Modern JavaScript**: ES2022+ features, native async/await, modules-first approach
- **Production Alignment**: Exact architectural parity with proven production pattern
  **Alternatives Considered:**
- Keep FastAPI: Rejected because sacrifices unified stack benefits, adds Python maintenance overhead
- Use Deno: Rejected because less ecosystem maturity and Railway support than Node.js
- tRPC/GraphQL instead of REST: Rejected because REST remains simpler for this template
  **Impact:**
- Architecture: `/src/config`, `/src/middleware`, `/src/routes`, `/src/services`, `/src/types` structure
- Build: TypeScript → JavaScript via `tsc && tsc-alias` (path alias rewriting required for ESM)
- Startup: Lazy singleton `getEnvironment()` validates all vars at import time; fails fast on misconfiguration
- Runtime: Express 5 + ioredis + Supabase JS client
- Deployment: Unchanged (Vercel for web, Railway for api); nixpacks now uses nodejs_22 instead of Python 3.11
- Documentation: CLAUDE.md, README.md updated; Vercel manual root directory setup required post-deployment
  **Time Spent:** ~2 hours (planning, implementation, testing, documentation)
  **Learnings:**

1. **ESM .js Extension Requirement**: TypeScript with `"module": "esnext"` does not rewrite import extensions. Must write `import { foo } from "@/lib/bar.js"` even in `.ts` files. Node.js ESM requires explicit extensions at runtime. Missing extensions cause "Cannot find module" errors.
2. **tsc-alias is Essential**: `tsc` leaves `@/*` path aliases as-is; `node` fails at startup. Build script must be `tsc && tsc-alias`.
3. **Railway IPv6 Dual-Stack**: ioredis needs `family: 0` (AF_UNSPEC) to support Railway's internal Redis hostname resolution (IPv6 preferred, falls back to IPv4).
4. **getEnvironment() Lazy Singleton Pattern**: Centralizes env validation, called at module import time (not async). Validates everything on first call; caches result. `process.exit(1)` on validation failure prevents startup.
5. **Zod vs Pydantic**: Zod is runtime-first; types are inferred from schemas via `z.infer<typeof schema>`. Pydantic works opposite (types first, validation second). Zod better for APIs where request/response shapes are primary concern.
6. **package-lock.json Requirement**: Railway uses `npm ci` during build (requires committed lockfile). Contrast with Python which allows `pip install` without lockfile. Must commit `package-lock.json`.
7. **Supabase Health Check (42P01)**: For fresh templates with no tables, querying a non-existent table returns PostgreSQL error 42P01 (table not found). This still confirms connectivity; "success" in health check logic.
8. **vercel.json Simplification Trade-off**: Removing `buildCommand` and `outputDirectory` overrides forces manual dashboard setup (root directory → apps/web). Benefit: simpler config, clearer Vercel auto-detection. Cost: one-time manual step.
9. **Monorepo Root Relative Imports**: From `apps/api/src/services/supabase.ts`, path `@/../../supabase/types.js` resolves correctly because `tsconfig.json` has `rootDir: "."` (not `"./src"`), allowing includes outside `src/`.
10. **Error Response Shape Differences**: FastAPI returns `{"detail": "..."}` on validation errors. Express http-errors returns `{"error": "...", "status": ...}`. Frontend `lib/api.ts` must check both fields: `errorData.message || errorData.detail || ...`.

**Files Modified:**

- Deleted: `main.py`, `supabase_utils.py`, `requirements.txt`, Python deployment configs
- Created: Full Express structure (src/config, src/middleware, src/routes, src/services, src/types)
- Renamed: `apps/frontend/` → `apps/web/`
- Updated: CLAUDE.md (Node.js sections, Express style guide, removed Python sections), README.md (tech stack, quickstart), web app (page.tsx, about/page.tsx, metadata.ts, lib/api.ts)

**Next Steps (for projects using this template):**

1. Fill in Supabase credentials in `apps/api/.env`
2. Regenerate `apps/api/supabase/types.ts` with actual schema: `npx supabase gen types typescript --project-id YOUR_ID > supabase/types.ts`
3. Set `NEXT_PUBLIC_API_URL` in `apps/web/.env.local`
4. After Vercel deployment, manually set root directory to `apps/web` in dashboard

<!-- New log entries go below this line -->

## 2026-03-17 - Supabase Folder Relocation to apps/shared

**Type:** Refactor
**Change:** Moved `apps/api/supabase/` → `apps/shared/supabase/` to share Supabase types and migrations across services.
**Rationale:** A shared database schema belongs at the monorepo level, not scoped to a single service.
**Impact:**

- `apps/api/tsconfig.json`: `rootDir` changed from `"."` to `".."` (apps/) to include the shared folder; `paths` gained `@shared/*`; `include` updated to `../shared/supabase/**/*`
- Build output path changed from `dist/src/index.js` → `dist/api/src/index.js` (consequence of rootDir change); updated in `package.json`, `railway.json`, `nixpacks.toml`
- Import in `services/supabase.ts`: `@/../../supabase/types.js` → `@shared/supabase/types.js`
- Regeneration command: `npx supabase gen types typescript --project-id YOUR_ID > apps/shared/supabase/types.ts`
- **Note:** Prior log entry (item 9 above) describing `rootDir: "."` and `@/../../supabase/types.js` is superseded by this change.

## 2026-06-04 11:32 PT - Migrate Tailwind CSS v3 → v4

**Type:** Refactor
**Change:** Upgraded `tailwindcss` 3.4.x → 4.3.0 in `apps/web`. Swapped PostCSS plugin to `@tailwindcss/postcss`, removed `autoprefixer` (built into v4), added `postcss-load-config` as an explicit devDep (was transitive via Tailwind v3). Deleted `tailwind.config.ts` — v4 auto-detects content and config moved to CSS: `@import "tailwindcss"` + `@theme inline` block in `globals.css` mapping `--color-background`/`--color-foreground` to the existing CSS vars. Renamed utilities per the official upgrade guide: bare `rounded` → `rounded-sm`, bare `shadow` → `shadow-sm`, `focus:outline-none` → `focus:outline-hidden`, `bg-gradient-to-r` → `bg-linear-to-r`. Added `@layer base` rule restoring `cursor: pointer` on buttons (v4 preflight defaults to `cursor: default`). Dropped unused custom `.text-balance` utility (built into v4).
**Rationale:** v3 is in LTS maintenance; v4 is the current major with CSS-first config, faster builds, and automatic content detection.
**Alternatives Considered:** `npx @tailwindcss/upgrade` codemod — codebase is small enough that a manual, audited migration was safer and produced a cleaner diff.
**Impact:** No visual changes intended. Verified: all borders already specify explicit colors (v4 default changed to currentColor), `ring` usage already has explicit width/color (v4 default ring changed 3px→1px), no removed-in-v4 utilities (`bg-opacity-*`, `flex-shrink-*`, etc.) were in use. Placeholder text now uses v4 default (currentColor at 50%) instead of gray-400 — acceptable, near-identical. Browser floor rises to Safari 16.4+/Chrome 111+/Firefox 128+.
**Learnings:** Next 16/Turbopack loads `postcss.config.ts` fine with `@tailwindcss/postcss`. `@theme inline` only emits theme tokens actually used in markup. `postcss-load-config` types must be a direct devDep once Tailwind v3 is gone.

## 2026-06-11 16:32 PT - Upgrade all packages to latest (TypeScript 6, ESLint 10, Node 24 LTS)

**Type:** Decision | Implementation
**Change:** Upgraded every dependency across all workspaces to its latest version, including breaking majors: TypeScript 5.9.3 → 6.0.3 (all apps), ESLint 9 → 10.4.1, lint-staged 16 → 17.0.7, @supabase/ssr 0.10.2 → 0.12.0, @types/node 22 → 25 (web), Node 22 → 24 LTS (Dockerfile `node:24-alpine`, `engines` >=24). Minors/patches: Next 16.2.9, React 19.2.7, supabase-js 2.108.1, tRPC 11.17.0, TanStack Query 5.101.0, Zod 4.4.3, Express 5.2.1, ai 6.0.202, @langfuse/\* 5.4.1, @opentelemetry/sdk-node 0.219.0, ioredis 5.11.1, Biome 2.4.16, prettier 3.8.4, sql-formatter 15.8.1, posthog-js/node, tsx, tsc-alias, etc. Tailwind 4.3.0 was already latest.
**Rationale:** Stay current; TS 6.0 is the final JS-based compiler before the Go-native TS 7. Node 24 is Active LTS (until Apr 2028) and Vercel's default; Railway uses our Dockerfile so the base image controls the runtime.
**Alternatives Considered:** Holding TS at 5.9 (typescript-eslint caps at <6.1, but eslint-config-next allows >=3.3 and Next 16 has no TS peer dep — no blocker). `npm audit fix --force` for Next's internally-pinned postcss <8.5.10 (moderate, build-time) — rejected, it would downgrade Next to v9; upstream issue.
**Impact:**

- TS 6 migration: `module`/`moduleResolution` `esnext`/`node` → `nodenext` in apps/api and apps/cron tsconfigs; removed deprecated `baseUrl` (paths now relative to tsconfig); cron needed explicit `"types": ["node"]` and a direct `@types/node` devDep.
- `apps/api/src/services/redis.ts`: `import Redis from 'ioredis'` → `import { Redis } from 'ioredis'` (CJS default-import typing changes under nodenext).
- Fixed 21 pre-existing Biome `useBlockStatements` violations (brace-less single-line `if`s) across api/web so `lint:js:check` is green.
- `npm audit fix` cleared path-to-regexp/picomatch/qs advisories in api and web.
- Verified: `npm run typecheck`, api/web/cron builds, Biome check all green; API smoke-boots with `/health` → `{"status":"ok"}`, Redis connects, graceful shutdown works.

**Learnings:** TS 6.0 defaults `strict: true` and no longer honors the legacy `node` (node10) resolution without `ignoreDeprecations`; `nodenext` is the right setting for ESM packages that already use `.js` import extensions. lint-staged 17 requires Node >=22.22.1 and git >=2.32. @supabase/ssr 0.12 tightened its supabase-js peer to ^2.108.0 — bump them together.

## 2026-06-11 16:56 PT - Prompts move to codebase; Langfuse scoped to tracing/sessions; MCP config committed

**Type:** Decision | Implementation
**Change:** Enforced the new CLAUDE.md LLM policies in code: (1) created `apps/api/src/prompts/index.ts` as the single source of truth for LLM prompts (typed registry, `{{variable}}` interpolation via `compilePrompt`, `getPrompt` with example-prompt fallback); removed prompt fetching from `services/langfuse.ts` (no more `langfuseClient.getPrompt`) — Langfuse is now tracing/sessions only. (2) `langfuse.getPrompt` tRPC procedure reads from the codebase and works without Langfuse keys. (3) `langfuse.traceExample` now always groups spans into a session (`anon-<uuid>` fallback when the client omits sessionId) and carries an Anthropic prompt-caching breakpoint (`providerOptions.anthropic.cacheControl` on the last tool) as the pattern to copy. (4) Committed repo-root `.mcp.json` preconfiguring Vercel (HTTP), Railway (stdio), and Supabase (stdio, `--read-only`, `${SUPABASE_ACCESS_TOKEN}`) MCP servers. README + CLAUDE.md synced (features list, code org tree, snippet, curl now uses `/trpc/langfuse.traceExample` with `x-trpc-source`).
**Rationale:** CLAUDE.md policy "Langfuse (Tracing Yes, Prompts No)": prompts in git are version-controlled with the code that uses them and readable by terminal agents as context; Langfuse prompt management would split the source of truth. Supabase MCP is read-only per the least-privilege posture.
**Alternatives Considered:** Keeping the Langfuse `getPrompt` with codebase fallback (rejected — contradicts policy and silently prefers the remote copy).
**Impact:** `langfuse.getPrompt` response shape changed: `{ source, promptName, requestedName, found, prompt, variables }` (was `{ langfuseAvailable, promptName, prompt, variables, promptObj }`). No web-app callers existed. Verified: api/web typecheck + builds green, Biome green, smoke test confirms prompt rendering + fallback + new startup messages without Langfuse keys.
**Learnings:** tRPC GET queries take URL-encoded JSON via `?input=`; the API requires an `x-trpc-source` header. AI SDK v6 accepts `providerOptions` inside `tool({...})` for per-tool cache breakpoints.

## 2026-06-11 17:08 PT - PR self-review round: prompts hardening, tests, dead-ESLint removal, doc accuracy

**Type:** Bug Fix | Implementation
**Change:** Full line-by-line review of PR #69 (two parallel review agents + manual pass) produced: (1) two real bugs fixed in `src/prompts/index.ts` — `isPromptName` used `in` (prototype members like 'toString' passed the guard → runtime TypeError); `compilePrompt` used string-form `replaceAll` (values containing `$$`/`$&` were corrupted) — now `Object.hasOwn` + function replacer. (2) First unit tests in the repo: 20 `node:test` cases for the prompts module (`npm test` in apps/api, runs via `tsx --test`); test-driven discovery caught both bugs. (3) Conventions: `found` → `wasFound` (boolean prefix rule); `'example'` magic string → `FALLBACK_PROMPT_NAME`; dropped redundant `String(sessionId)` (schema already guarantees string; `||` deliberately coerces `''` to the generated anon ID). (4) Fail-closed: `langfuse.getPrompt` now throws `NOT_FOUND` for unregistered prompt names (module-level `getPrompt` stays total and returns `wasFound: false`); procedure gained an `.output(PromptResponseSchema)`. (5) Removed dead ESLint: web's `lint` script was `next lint`, which Next 16 removed, and no ESLint config existed — script now delegates to root Biome (`npm --prefix ../.. run lint:js:check`); uninstalled unused `eslint` + `eslint-config-next`. (6) `railway.json` startCommand now includes `--expose-gc`, matching the Dockerfile CMD it overrides. (7) README brought current: structure tree gained apps/cron, src/prompts, .mcp.json, biome.json; tRPC curl examples gained the required `x-trpc-source` header; Testing section now documents real `npm test` (api) and no-runner-yet (web); Database Migrations section replaced the Prisma instructions with the actual `.up.sql`/`.down.sql` manual-run policy; `.mcp.json` documented under AI-assisted development.
**Rationale:** The review checklist (spec compliance, all code paths happy/sad, conventions, DRY, fail-closed) is from the user's standing instructions; both review agents independently confirmed the same two prompt bugs.
**Impact:** `langfuse.getPrompt` breaking change: unknown names now 404 instead of HTTP 200 with a fallback prompt (no existing callers). ESLint fully out of the web app — Biome is the single linter.
**Learnings:** `String.prototype.replaceAll` with a _string_ pattern still interprets `$` patterns in a string replacement — use a function replacer for literal substitution. `'toString' in obj` is true for any plain object; `Object.hasOwn` is the registry-membership check. `next lint` no longer exists in Next 16 (it parses `lint` as a directory argument).

## 2026-06-11 17:34 PT - Aggressive Prefetching Doctrine + Primitives

**Type:** [Decision | Implementation]
**Change:** Updated CLAUDE.md prefetching doctrine to apply regardless of app size (was "small number of pages"), added previous-page warming to the paginated-table rule, and added the Loading Indicators rule (show a small loading dialog only after 200ms, never with a scrim). Implemented the doctrine in apps/web: `lib/prefetch/` (usePrefetchPages, useHoverPrefetch, usePaginationPrefetch, runWhenIdle, topLevelRoutes registry), `components/PagePrefetcher.tsx` mounted in the root layout, and `components/ui/LoadingDialog.tsx` (+ useDelayedLoading) wired into LogoutButton.
**Rationale:** Prefetching both route bundles and data queries makes navigation feel instant; deferring via requestIdleCallback keeps it non-blocking. A 200ms-delayed, scrim-less dialog avoids flash on fast operations.
**Impact:** New top-level pages must be registered in `lib/prefetch/routes.ts` and their queries in `usePrefetchPages`. Tables/tabs added later should use the hover/pagination hooks rather than reinventing.
**Learnings:** `'requestIdleCallback' in window` narrows `window` to `never` under current DOM lib types — use `typeof window.requestIdleCallback === 'function'` instead.
