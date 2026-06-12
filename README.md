# Next.js + Node.js Template

A template for rapidly spinning up full-stack applications with Next.js frontend and Express/Node.js backend services.

## Features

- **Authentication**: Supabase Auth with email+password, Google OAuth, and Microsoft OAuth (all free)
- **Modern Frontend**: Next.js 16 with React 19, TypeScript, Tailwind CSS v4, Radix UI, shadcn/ui
- **Robust Backend**: Express 5 + tRPC v11 with Node.js 24+, TypeScript, end-to-end type safety
- **End-to-End Type Safety**: tRPC v11 + TanStack Query v5 for type-safe API calls with automatic caching
- **Supabase Integration**: PostgreSQL database with built-in auth, realtime, and storage
- **Redis Integration**: Built-in caching with Railway-optimized connection settings
- **Vercel AI SDK**: First-class LLM integration with Claude Haiku, streaming, and tool calls
- **Langfuse Integration**: Optional LLM observability for tracing and sessions (prompts live in the codebase, not Langfuse)
- **PostHog Analytics**: Optional web analytics and product analytics with managed reverse proxy support
- **Deployment Ready**: Pre-configured for Vercel (frontend) and Railway (backend + Redis)
- **Monorepo Structure**: Organized multi-service architecture
- **Best Practices**: Includes CLAUDE.md for comprehensive AI-assisted development guidelines
- **Comprehensive Documentation**: Decision logging and development workflow templates

## Tech Stack

### Frontend

- **Framework**: Next.js 16
- **UI Library**: React 19
- **Language**: TypeScript 6+
- **Styling**: Tailwind CSS v4 (CSS-first configuration via `@theme` in `globals.css`)
- **UI Components**: Radix UI, shadcn/ui
- **Data Fetching**: TanStack Query v5 (via tRPC)
- **Deployment**: Vercel

### Backend

- **Framework**: Express 5
- **Runtime**: Node.js 24+
- **Language**: TypeScript with ESM modules
- **API Layer**: tRPC v11 (type-safe procedures) + Zod (schemas + inferred types)
- **Database**: Supabase (PostgreSQL with auth, realtime, storage)
- **Caching**: Redis (ioredis with Railway-optimized settings)
- **AI**: Vercel AI SDK (`ai` + `@ai-sdk/anthropic`) — `generateText`, `streamText`, tool calls
- **Observability**: Langfuse (optional: tracing, sessions; prompts live in the codebase at `apps/api/src/prompts/`)
- **Deployment**: Railway (API + Redis plugin)

### Why tRPC (not REST)?

We intentionally chose tRPC over a REST API. The API is consumed only by our own TypeScript frontend, so we get end-to-end type safety with zero codegen: the web app imports the `AppRouter` _type_ directly from `apps/api/src/trpc/router.ts`, and every procedure's input/output types (defined once as Zod schemas) flow into React components. There is no OpenAPI spec to maintain and no client to regenerate — the contract _is_ the code, so it can never drift.

This matters doubly for AI-assisted development (a core goal of this template). With REST, a coding agent's most common failure mode — hallucinating a plausible endpoint or payload shape — surfaces only at runtime as a 404. With tRPC it's a compile error caught by a cheap `tsc` run. Call sites are typed property accesses (`trpc.health.check`) rather than URL strings, so agents (and humans) can discover the full API surface by reading the routers, find every caller mechanically, and verify cross-stack refactors exhaustively with the typechecker instead of needing the app running.

It's still plain HTTP + JSON underneath (queries are GETs, mutations are POSTs to `/trpc/*`), so `curl`, CORS, load balancers, and Railway deployment all work as usual. The trade-off: there's no language-neutral spec, so if you ever need to expose an API to third parties or non-TypeScript clients, add a REST/OpenAPI layer alongside for that surface.

## Project Structure

```
.
├── apps/
│   ├── web/                  # Next.js application
│   │   ├── app/
│   │   │   ├── (auth)/               # Auth pages (login, signup, reset-password, etc.)
│   │   │   │   ├── login/page.tsx
│   │   │   │   ├── signup/page.tsx
│   │   │   │   ├── reset-password/page.tsx
│   │   │   │   ├── update-password/page.tsx
│   │   │   │   ├── auth/callback/route.ts      # OAuth callback handler
│   │   │   │   ├── auth/auth-code-error/page.tsx
│   │   │   │   └── layout.tsx
│   │   │   ├── (dashboard)/          # Protected dashboard pages
│   │   │   │   ├── dashboard/page.tsx
│   │   │   │   └── layout.tsx        # Auth guard + header
│   │   │   ├── .well-known/          # Microsoft domain verification
│   │   │   ├── layout.tsx            # Root layout (Providers)
│   │   │   └── page.tsx              # Home page
│   │   ├── public/sso/              # OAuth provider logos (Google, Microsoft SVGs)
│   │   ├── components/
│   │   │   ├── providers/TRPCProvider.tsx  # tRPC + auth headers
│   │   │   └── LogoutButton.tsx
│   │   ├── lib/
│   │   │   ├── supabase/             # Supabase clients
│   │   │   │   ├── client.ts         # Browser client
│   │   │   │   ├── server.ts         # Server client (RSC)
│   │   │   │   ├── middleware.ts      # Session updater (proxy)
│   │   │   │   ├── service.ts        # Admin client (secret key)
│   │   │   │   └── check-invite.ts   # Invitation gating (server action)
│   │   │   ├── utils/admin.ts        # Admin email domain check
│   │   │   └── trpc.ts              # tRPC client context
│   │   ├── proxy.ts                  # Next.js 16 middleware (route protection)
│   │   ├── package.json
│   │   └── .env.example
│   ├── api/                  # Express + tRPC API service
│   │   ├── src/
│   │   │   ├── index.ts              # Express app + tRPC mount + server start
│   │   │   ├── config/
│   │   │   │   └── environment.ts    # Zod env validation
│   │   │   ├── middleware/
│   │   │   │   ├── cors.ts           # CORS configuration
│   │   │   │   └── errorHandler.ts   # Error handling
│   │   │   ├── prompts/              # LLM prompts (codebase source of truth) + tests
│   │   │   ├── trpc/
│   │   │   │   ├── init.ts           # Context, createRouter, publicProcedure, middleware
│   │   │   │   ├── middleware.ts      # Auth middleware (authenticatedProcedure, etc.)
│   │   │   │   ├── router.ts         # Root router, exports AppRouter type
│   │   │   │   └── routers/          # Sub-routers (health, redis, etc.)
│   │   │   ├── services/             # Redis, Supabase, Langfuse, telemetry clients
│   │   │   └── types/                # Zod schemas & types
│   │   ├── package.json
│   │   ├── tsconfig.json
│   │   ├── Dockerfile                # Docker build (node:24-alpine, used by Railway)
│   │   └── .env.example
│   ├── cron/                 # Scheduled jobs (e.g. Supabase keep-alive ping)
│   │   ├── src/
│   │   ├── package.json
│   │   └── tsconfig.json
│   └── shared/               # Shared assets across services
│       └── supabase/
│           ├── types.ts              # Generated Supabase types
│           └── migrations/           # SQL migrations (.up.sql/.down.sql pairs, run manually)
├── docs/
│   └── AGENTS_APPENDLOG.md   # Decision log (append-only)
├── scripts/
│   └── test_services.sh      # Service connectivity test script
├── .entire/                  # entire.io agent session logger (see below)
│   └── settings.json         # Logging config (committed; logs gitignored internally)
├── .mcp.json                 # MCP servers for AI agents (Vercel, Railway, Supabase read-only)
├── AGENTS.md                 # AI agent entry point (redirects to CLAUDE.md)
├── CLAUDE.md                 # Comprehensive development guidelines and best practices
├── biome.json                # JS/TS formatting and linting rules
├── vercel.json               # Vercel deployment config
├── railway.json              # Railway deployment config (Dockerfile builder → apps/api)
├── .vercelignore             # Vercel ignore patterns
├── .gitignore                # Comprehensive ignore patterns
└── README.md                 # This file
```

## Quick Start

### Prerequisites

- Node.js 24.0.0 or higher
- npm or yarn
- [Supabase account](https://supabase.com) (free tier available)

### Supabase Setup

1. **Create a Supabase project**:
   - Go to [https://app.supabase.com](https://app.supabase.com)
   - Click "New Project"
   - Choose an organization, project name, database password, and region

2. **Get your credentials**:
   - Go to Project Settings → API
   - Copy your `Project URL` (SUPABASE_URL)
   - Copy your `publishable key` (starts with `sb_publishable_`) - required for frontend auth
   - Copy your `secret key` (starts with `sb_secret_`) (SUPABASE_SECRET_KEY) - **Keep this secret!**

3. **Add to `.env` file** (see Backend Setup below)

### Supabase Auth Setup

After creating your Supabase project, configure authentication providers:

1. **Auth > Providers > Email**: Email+password sign-in is enabled by default.

2. **Auth > Providers > Google**: Enable and paste your Client ID + Client Secret.
   - Register an OAuth client at: [https://console.cloud.google.com/auth/clients](https://console.cloud.google.com/auth/clients)
   - Create an OAuth 2.0 Client ID (type: "Web application")
   - Set the **Authorized redirect URI** to the "Callback URL (for OAuth)" shown in the Google panel at [`https://supabase.com/dashboard/project/{PROJECT_ID}/auth/providers`](https://supabase.com/dashboard/project/{PROJECT_ID}/auth/providers)

3. **Auth > Providers > Azure (Microsoft)**: Enable and paste your Client ID + Client Secret. Follow these steps in order:
   - Register an OAuth client at: [https://portal.azure.com/#view/Microsoft_AAD_IAM/ActiveDirectoryMenuBlade/~/Overview](https://portal.azure.com/#view/Microsoft_AAD_IAM/ActiveDirectoryMenuBlade/~/Overview) --> Add --> App registration, with "Any Entra ID Tenant + Personal Microsoft accounts" supported account types and "Web" platform for Redirect URI
   - Set the **Redirect URI** to the "Callback URL (for OAuth)" that is shown in Supabase Auth's Azure panel at [`https://supabase.com/dashboard/project/{PROJECT_ID}/auth/providers`](https://supabase.com/dashboard/project/{PROJECT_ID}/auth/providers)
   - Register verified custom domain names at: [https://entra.microsoft.com/#view/Microsoft_AAD_IAM/DomainsManagementMenuBlade/~/CustomDomainNames](https://entra.microsoft.com/#view/Microsoft_AAD_IAM/DomainsManagementMenuBlade/~/CustomDomainNames)
   - Register verified custom URL domains at: [https://entra.microsoft.com/#view/Microsoft_AAD_IAM/DomainsManagementMenuBlade/~/CustomUrlDomains](https://entra.microsoft.com/#view/Microsoft_AAD_IAM/DomainsManagementMenuBlade/~/CustomUrlDomains)

4. **Auth > URL Configuration > Site URL**: Set to your app's base URL (e.g., `http://localhost:3000` for dev, `https://myapp.com` for prod).

5. **Auth > URL Configuration > Redirect URLs**: Add `http://localhost:3000/auth/callback` for dev, `https://myapp.com/auth/callback` for prod.

Without steps 2-3, OAuth buttons will error. Without steps 4-5, Supabase will reject redirect URLs as unauthorized.

> **Cost:** Supabase Auth (including email+password), Google OAuth, and Microsoft/Azure OAuth are all **free** to use. No paid plans are required for any of these auth providers.

#### Microsoft Domain Verification (`.well-known`)

The template includes `.well-known/microsoft-identity-association.json` route handlers that serve Azure domain verification JSON. This allows Microsoft to verify that your domain owns the OAuth client ID, which is required for custom domain branding in the Azure login flow. Set the `AZURE_OAUTH_CLIENT_ID` environment variable to enable it. If not set, the endpoint returns a 404. Azure may request this file at either `/.well-known/microsoft-identity-association.json` or `/.well-known/microsoft-identity-association` — both paths are handled.

#### Auth Environment Variables

| Variable                               | Location                                | Description                                                                  |
| -------------------------------------- | --------------------------------------- | ---------------------------------------------------------------------------- |
| `NEXT_PUBLIC_SUPABASE_URL`             | `apps/web/.env.local`                   | Supabase project URL (public)                                                |
| `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY` | `apps/web/.env.local`                   | Supabase publishable key (public)                                            |
| `SUPABASE_SECRET_KEY`                  | `apps/web/.env.local`                   | Supabase secret key (server-only)                                            |
| `SUPABASE_COOKIE_DOMAIN`               | `apps/web/.env.local`                   | Optional. For cross-subdomain cookies (e.g. `.myapp.com`)                    |
| `INVITED_EMAILS`                       | `apps/web/.env.local`                   | Optional. Comma-separated list of allowed emails. Empty = open signup        |
| `ADMIN_EMAIL_DOMAIN`                   | `apps/web/.env.local` + `apps/api/.env` | Optional. Emails `@this-domain` bypass invite check and get admin privileges |
| `INTERNAL_API_KEY`                     | `apps/api/.env`                         | Optional. For server-to-server auth bypass                                   |
| `AZURE_OAUTH_CLIENT_ID`                | `apps/web/.env.local`                   | Optional. Enables `.well-known` Microsoft domain verification endpoint       |
| `BYPASS_AUTH`                          | `apps/api/.env`                         | Dev only. Set to `true` to bypass auth entirely (never in production)        |

#### CSRF Protection

The `x-trpc-source` header is sent on all tRPC requests. Its value is arbitrary (e.g., `'nextjs-client'`) — the backend only checks for its _existence_, not its value. The purpose is to force a CORS preflight, which prevents cross-site form attacks since browsers cannot send custom headers on cross-origin requests without one.

### PostHog Analytics Setup (Optional)

[PostHog](https://posthog.com) provides web analytics and product analytics (free tier available). The template includes client-side and server-side PostHog integration that activates when you set the environment variables.

1. **Create a PostHog project** at [https://us.posthog.com](https://us.posthog.com) (free).

2. **Get your project API key** from Project Settings.

3. **Enable Web Analytics** at [`https://us.posthog.com/project/{PROJECT_ID}/settings/project-web-analytics`](https://us.posthog.com/project/{PROJECT_ID}/settings/project-web-analytics).

4. **Set environment variables**:
   - `NEXT_PUBLIC_POSTHOG_KEY` in `apps/web/.env.local` — your project API key
   - `NEXT_PUBLIC_POSTHOG_HOST` in `apps/web/.env.local` — API host (default: `https://us.i.posthog.com`)
   - `POSTHOG_API_KEY` in `apps/api/.env` — same project API key (for server-side events)
   - `POSTHOG_HOST` in `apps/api/.env` — same API host

5. **Set up a managed reverse proxy** (recommended) at [`https://us.posthog.com/project/{PROJECT_ID}/settings/organization-proxy`](https://us.posthog.com/project/{PROJECT_ID}/settings/organization-proxy). This routes PostHog requests through your own subdomain (e.g. `https://analytics.myapp.com`), which prevents adblockers from blocking analytics. Set `NEXT_PUBLIC_POSTHOG_HOST` to your proxy URL.

6. **View your analytics** at [`https://us.posthog.com/project/{PROJECT_ID}/web`](https://us.posthog.com/project/{PROJECT_ID}/web).

If PostHog is not configured, all analytics calls silently no-op — no errors, no impact on the app.

#### PostHog Environment Variables

| Variable                   | Location              | Description                                            |
| -------------------------- | --------------------- | ------------------------------------------------------ |
| `NEXT_PUBLIC_POSTHOG_KEY`  | `apps/web/.env.local` | PostHog project API key (public)                       |
| `NEXT_PUBLIC_POSTHOG_HOST` | `apps/web/.env.local` | PostHog API host or reverse proxy URL                  |
| `POSTHOG_API_KEY`          | `apps/api/.env`       | Same project API key (for server-side events)          |
| `POSTHOG_HOST`             | `apps/api/.env`       | PostHog API host (default: `https://us.i.posthog.com`) |

#### Built-in Events

The template captures these events out of the box:

| Event             | Location         | Properties                 |
| ----------------- | ---------------- | -------------------------- |
| `user_logged_in`  | Login page       | `method: email`            |
| `user_logged_in`  | OAuth callback   | `method: google` / `azure` |
| `user_signed_up`  | Signup page      | `method: email`            |
| PostHog identify  | Dashboard layout | `userId`, `email`          |
| `user_logged_out` | Logout button    | —                          |
| PostHog reset     | Logout button    | Clears identity            |

### Frontend Setup

```bash
cd apps/web
npm install
cp .env.example .env.local
# Add NEXT_PUBLIC_API_URL=http://localhost:8000 to .env.local
npm run dev
```

Visit [http://localhost:3000](http://localhost:3000)

### Backend Setup

```bash
cd apps/api
npm install
cp .env.example .env
# Add your Supabase credentials and Redis URL to .env
npm run dev
```

API server running at [http://localhost:8000](http://localhost:8000)

**Test endpoint:** [http://localhost:8000/health](http://localhost:8000/health)

**Note:** After installing any new npm package, commit both `package.json` and `package-lock.json`

### Redis Setup (Optional for Local Development)

The API uses Redis for caching. For local development, you can either:

**Option 1: Run Redis locally**

```bash
# macOS (using Homebrew)
brew install redis
brew services start redis

# Ubuntu/Debian
sudo apt-get install redis-server
sudo systemctl start redis

# Docker
docker run -d -p 6379:6379 redis:latest
```

**Option 2: Skip Redis locally**

The API gracefully degrades if Redis is unavailable. You can develop without Redis, and it will simply skip caching operations.

**Test Connections**

Once the API is running, test connectivity using the included test script:

```bash
# Run the comprehensive test script
bash scripts/test_services.sh
```

The test script will check:

- API root endpoint connectivity
- Health check endpoint
- Redis connection and operations
- Supabase connection and operations

**Alternative: Manual testing with curl**

```bash
# Infrastructure health probe
curl http://localhost:8000/health

# tRPC endpoints require the x-trpc-source header (CSRF protection — see above)
# Detailed health check (via tRPC)
curl -H "x-trpc-source: curl" http://localhost:8000/trpc/health.check

# Test Redis
curl -H "x-trpc-source: curl" http://localhost:8000/trpc/redis.test

# Test Supabase
curl -H "x-trpc-source: curl" http://localhost:8000/trpc/supabase.test
```

## Deployment

### Frontend (Vercel)

1. Connect your repository to Vercel (via GitHub integration)
2. Vercel will automatically detect the `vercel.json` configuration
3. Set environment variables in Vercel dashboard
4. Deploy

The `vercel.json` is simplified — Vercel auto-detects Next.js:

- Deploy on pushes to `main` and `develop` branches
- After deploying, set root directory to `apps/web` in the Vercel dashboard (Settings → General → Root Directory)

### Backend (Railway)

Each service under `apps/` can be deployed independently to Railway.

**Deploying the API service:**

1. Create a new service in Railway
2. Connect your repository (via GitHub integration)
3. **Keep the service root directory at the repo root** — the root `railway.json` uses the `DOCKERFILE` builder pointing at `apps/api/Dockerfile`, and the Dockerfile needs repo-root build context to copy `apps/shared/` alongside `apps/api/`
4. Railway will automatically detect the root `railway.json` and build the Dockerfile
5. **Add Redis plugin**: Click "New" → "Database" → "Add Redis"
   - Railway will automatically set the `REDIS_URL` environment variable
   - The API is configured with Railway-compatible settings (socket family 0 for IPv6/IPv4 dual-stack)
6. **Set Supabase environment variables** in Railway dashboard:
   - `SUPABASE_URL`: Your Supabase project URL
   - `SUPABASE_SECRET_KEY`: Your Supabase secret key (starts with `sb_secret_`) (keep secret!)
7. Set other environment variables (CORS_ORIGINS, etc.)
8. Deploy

**Deployment configuration files:**

- `railway.json` (repo root) - Deployment configuration (Dockerfile builder, start command, restart policy)
- `apps/api/Dockerfile` - Build configuration (`node:24-alpine`, `npm ci` + `npm run build`)
- `apps/api/package.json` / `package-lock.json` - Node.js dependencies for this service

The `railway.json` is configured for:

- Docker builds from `apps/api/Dockerfile`
- Start command `node dist/api/src/index.js`
- Automatic restarts on failure (up to 10 retries)

The API also exposes a `/health` endpoint (tests both Redis and Supabase) that can be used as a Railway health check.

**Service Configuration:**

- **Redis**: Socket keepalive with TCP settings optimized for Railway
- **Supabase**: Works with any Supabase project (no special Railway plugin needed)
- **Graceful degradation**: API continues to work if services are unavailable
- **Connection retry**: Includes retry strategy with exponential backoff

### Adding More Backend Services

To add additional backend services:

1. Create new service directory under `apps/` (e.g., `apps/worker/`)
2. Add service-specific configuration files:
   - `Dockerfile` - Build configuration (Node.js 24; copy `apps/shared/` too if the service uses shared types)
   - `package.json` / `package-lock.json` - Node.js dependencies
   - `.env.example` - Environment variable template
3. Create a new Railway service in your project
4. Connect the same repository
5. Point the service at the new Dockerfile (set the config path to a service-specific `railway.json` with a `DOCKERFILE` builder, or set the Dockerfile path in the service settings)
6. Deploy independently

**Example structure for multiple services:**

```
apps/
├── web/              # Next.js frontend
│   ├── package.json
│   └── ...
├── api/              # Express + tRPC API service
│   ├── Dockerfile
│   ├── package.json
│   └── ...
├── worker/           # Background worker service
│   ├── Dockerfile
│   ├── package.json
│   └── ...
└── websocket/        # WebSocket service
    ├── Dockerfile
    ├── package.json
    └── ...
```

Each service is independently deployable with its own configuration and dependencies. Not only does such a structure reduce coupling, but it also speeds up development by allowing you to run one Claude instance per service simultaneously without encountering merge conflicts.

## Environment Variables

### Frontend (`apps/web/.env.local`)

```bash
NEXT_PUBLIC_APP_URL=http://localhost:3000
NEXT_PUBLIC_API_URL=http://localhost:8000

# Supabase (Required for auth)
NEXT_PUBLIC_SUPABASE_URL=https://your-project.supabase.co
NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY=sb_publishable_xxxxxxxxxxxxx
SUPABASE_SECRET_KEY=sb_secret_xxxxxxxxxxxxx

# Optional auth config
# SUPABASE_COOKIE_DOMAIN=.myapp.com
# INVITED_EMAILS=alice@example.com,bob@example.com
# ADMIN_EMAIL_DOMAIN=mycompany.com
# AZURE_OAUTH_CLIENT_ID=your-azure-app-client-id
```

### Backend (`apps/api/.env`)

```bash
PORT=8000
NODE_ENV=development

# Supabase (required)
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_SECRET_KEY=sb_secret_xxxxxxxxxxxxx

# Redis (required for caching)
REDIS_URL=redis://localhost:6379

# CORS (comma-separated origins)
CORS_ORIGINS=http://localhost:3000,http://localhost:3001

# Auth (optional)
# ADMIN_EMAIL_DOMAIN=mycompany.com
# INTERNAL_API_KEY=your-internal-api-key
# BYPASS_AUTH=true  # Dev only, never in production

# API Keys (as needed)
# ANTHROPIC_API_KEY=sk-ant-xxxxx
```

## Development Guidelines

### AI-Assisted Development

This template includes comprehensive documentation for AI-assisted development:

- **CLAUDE.md**: Comprehensive development guidelines, coding standards, workflows, and best practices
- **AGENTS.md**: Universal entry point for AI agents (redirects to CLAUDE.md)
- **docs/AGENTS_APPENDLOG.md**: Decision log for tracking architectural choices and learnings
- **.mcp.json**: Preconfigured MCP servers for AI agents — Vercel (HTTP), Railway, and Supabase (read-only; requires `SUPABASE_ACCESS_TOKEN` in your environment)

When working with AI assistants, they should:

1. Read `CLAUDE.md` for complete development guidelines
2. Read `README.md` for project overview and setup
3. Read `docs/AGENTS_APPENDLOG.md` (last ~100 lines) for recent changes
4. Log significant decisions in `docs/AGENTS_APPENDLOG.md`

### Agent Session Logging (entire.io)

This template uses [entire.io](https://entire.io/) to log Claude Code (and other coding agent) prompts and responses. The `.entire/` directory at the repo root stores the configuration:

- **`.entire/settings.json`** — committed; controls logging strategy and telemetry
- **`.entire/logs/`**, **`.entire/tmp/`**, **`.entire/metadata/`** — gitignored by `.entire/.gitignore`; contain the actual session data

The current config (`strategy: "manual-commit"`) means sessions are only persisted when you explicitly commit them. Telemetry is disabled.

### Code Quality Automation (Formatters & Linters)

This template includes automated code quality checks powered by **Biome**, **Prettier**, and **sql-formatter**:

**Pre-commit Hook** — Runs automatically before each commit:

```bash
npm run build:api    # Build API (emits declarations needed by web typecheck)
npm run typecheck:web # Type check frontend against API declarations
npx lint-staged      # Auto-format and lint only staged files
```

If any step fails, the commit is blocked. Fix issues and try again.

**Available npm scripts** (from root directory):

```bash
# Run all checks together (same as pre-commit)
npm run typecheck && npm run build && npm run format && npm run lint

# Run checks without fixing (just report issues)
npm run format:check
npm run lint:check

# Configuration files
.editorconfig             # Shell script formatting standards
biome.json               # JS/TS formatting and linting rules
.prettierrc              # Markdown formatter configuration
.sql-formatter.json      # PostgreSQL SQL formatting
.husky/pre-commit        # Pre-commit hook script
```

**Configuration details:**

- **Biome**: Single quotes, 2-space indent, 100-char line width, strict rules (no unused imports/vars, require `const`)
- **Prettier**: For markdown files with 100-char print width
- **sql-formatter**: PostgreSQL dialect with 2-space indent
- **EditorConfig**: Shell script formatting standards

The pre-commit hook ensures high code quality by catching issues early before they make it into the repository.

### Code Style

#### JavaScript/TypeScript

- Use arrow functions: `const foo = () => {}`
- Use modern ES6+ syntax (destructuring, spread, optional chaining)
- Prefer `const` over `let`, never use `var`
- Use async/await instead of promise chains

#### Node.js/Express

- Use ESM imports with explicit `.js` extensions in TypeScript source files
- Use `getEnvironment()` for env vars (never `process.env` directly)
- Define Zod schemas for request/response shapes; infer types with `z.infer<>`
- Define tRPC procedures using `publicProcedure.input(Schema).query(...)` or `.mutation(...)`
- Use `TRPCError` for procedure errors (not `http-errors`)

### Testing

Backend (unit tests via `node:test` + `tsx`, plus type checking):

```bash
cd apps/api
npm test           # runs src/**/*.test.ts
npm run type-check
```

Frontend (no test runner is configured yet — type checking is the gate):

```bash
cd apps/web
npm run type-check
```

## API Health

The Express backend provides the following endpoints (the `/trpc/*` endpoints require an `x-trpc-source` header — any value):

- Infrastructure probe: `http://localhost:8000/health` (minimal, for Railway/uptime checks; no header needed)
- Health check: `http://localhost:8000/trpc/health.check` (detailed service status via tRPC)
- Redis test: `http://localhost:8000/trpc/redis.test`
- Supabase test: `http://localhost:8000/trpc/supabase.test`
- Langfuse test: `http://localhost:8000/trpc/langfuse.test`
- Prompt rendering: `http://localhost:8000/trpc/langfuse.getPrompt` (codebase prompts from `apps/api/src/prompts/`)
- API info: `http://localhost:8000/trpc/info.get`

## Common Tasks

### Adding a New API Endpoint

1. Create a new router file in `apps/api/src/trpc/routers/`
2. Define Zod input/output schemas in `apps/api/src/types/index.ts`
3. Add the router to `apps/api/src/trpc/router.ts`
4. Run `npm run build:api` to emit updated type declarations for the frontend

### Adding a New Frontend Page

1. Create a new file in `apps/web/app/`
2. Follow Next.js App Router conventions
3. Import and use shared components from `components/`

### Customizing the Tailwind Theme

Tailwind CSS v4 uses CSS-first configuration — there is no `tailwind.config.ts`. All customization lives in `apps/web/app/globals.css`:

```css
/* Add design tokens (generates utilities like bg-brand, text-brand) */
@theme {
  --color-brand: oklch(0.6 0.2 250);
  --font-display: "Satoshi", sans-serif;
}

/* Add a custom utility */
@utility tab-4 {
  tab-size: 4;
}
```

Content sources are auto-detected (no `content` array needed). To scan additional paths, use `@source "../path";`. See the [Tailwind v4 docs](https://tailwindcss.com/docs/theme) for details.

### Database Migrations

Migrations live in `apps/shared/supabase/migrations/` as `.up.sql`/`.down.sql` pairs and are **documentation only** — they are never executed programmatically. Run them manually in the Supabase web UI (SQL Editor). Each `.up.sql` must be idempotent, start with fail-early guards, and include explicit `GRANT` + RLS statements; each `.down.sql` rolls back in reverse order. See CLAUDE.md ("SQL Migrations") for the full rules.

After schema changes, regenerate the TypeScript types:

```bash
npx supabase gen types typescript --project-id YOUR_ID > apps/shared/supabase/types.ts
```

## Troubleshooting

### Build Errors

- Frontend (`apps/web`): `npm run type-check` then `npm run build`
- Backend (`apps/api`): `npm run type-check` then `npm run build`

### CORS Issues

CORS is configured in `apps/api/src/middleware/cors.ts`. Update `CORS_ORIGINS` in your `.env` file:

```bash
CORS_ORIGINS=http://localhost:3000,https://yourapp.vercel.app
```

Localhost is always allowed automatically. Check server logs for `🚫 CORS rejected: <origin>` messages when debugging.

## Contributing

1. Follow the coding standards in `CLAUDE.md`
2. Log significant decisions in `docs/AGENTS_APPENDLOG.md`
3. Test changes thoroughly before committing
4. Keep commits focused and atomic

## License

MIT License - Feel free to use this template for your projects.

## Support

For issues and questions:

- Check the documentation in `docs/`
- Review `CLAUDE.md` for coding guidelines
- Open an issue in the repository
