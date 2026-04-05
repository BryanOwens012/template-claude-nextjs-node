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
