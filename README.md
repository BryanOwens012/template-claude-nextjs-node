# Next.js + Node.js Template

A production-ready template for rapidly spinning up full-stack applications with Next.js frontend and Express/Node.js backend services.

## Features

- **Modern Frontend**: Next.js 15+ with React 19, TypeScript, Tailwind CSS, Radix UI, shadcn/ui
- **Robust Backend**: Express 5 with Node.js 22+, TypeScript, Zod validation, and type safety
- **Supabase Integration**: PostgreSQL database with built-in auth, realtime, and storage
- **Redis Integration**: Built-in caching with Railway-optimized connection settings
- **Vercel AI SDK**: First-class LLM integration with Claude Haiku, streaming, and tool calls
- **Langfuse Integration**: Optional LLM observability for prompts, tracing, and sessions
- **Deployment Ready**: Pre-configured for Vercel (frontend) and Railway (backend + Redis)
- **Monorepo Structure**: Organized multi-service architecture
- **Best Practices**: Includes CLAUDE.md for comprehensive AI-assisted development guidelines
- **Comprehensive Documentation**: Decision logging and development workflow templates

## Tech Stack

### Frontend

- **Framework**: Next.js 15+
- **UI Library**: React 19
- **Language**: TypeScript 5+
- **Styling**: Tailwind CSS
- **UI Components**: Radix UI, shadcn/ui
- **Deployment**: Vercel

### Backend

- **Framework**: Express 5
- **Runtime**: Node.js 22+
- **Language**: TypeScript with ESM modules
- **Validation**: Zod (schemas + inferred types)
- **Database**: Supabase (PostgreSQL with auth, realtime, storage)
- **Caching**: Redis (ioredis with Railway-optimized settings)
- **AI**: Vercel AI SDK (`ai` + `@ai-sdk/anthropic`) — `generateText`, `streamText`, tool calls
- **Observability**: Langfuse (optional: prompt management, tracing, sessions)
- **Deployment**: Railway (API + Redis plugin)

## Project Structure

```
.
├── apps/
│   ├── web/                  # Next.js application
│   │   ├── app/             # Next.js app router
│   │   ├── components/      # React components (Radix UI, shadcn/ui)
│   │   ├── lib/             # Utilities and helpers
│   │   ├── package.json
│   │   └── .env.example
│   └── api/                  # Express service
│       ├── src/
│       │   ├── index.ts              # Express app + server
│       │   ├── config/
│       │   │   └── environment.ts    # Zod env validation
│       │   ├── middleware/
│       │   │   ├── cors.ts           # CORS configuration
│       │   │   └── errorHandler.ts   # Error handling
│       │   ├── routes/               # API route handlers
│       │   ├── services/             # Redis, Supabase clients
│       │   └── types/                # Zod schemas & types
│       ├── supabase/
│       │   ├── types.ts              # Generated Supabase types
│       │   └── migrations/
│       ├── package.json
│       ├── tsconfig.json
│       ├── railway.json              # Railway deployment config
│       ├── .railwayignore            # Railway ignore patterns
│       ├── nixpacks.toml             # Nixpacks build config
│       └── .env.example
├── docs/
│   └── AGENTS_APPENDLOG.md   # Decision log (append-only)
├── scripts/
│   └── test_services.sh      # Service connectivity test script
├── .entire/                  # entire.io agent session logger (see below)
│   └── settings.json         # Logging config (committed; logs gitignored internally)
├── AGENTS.md                 # AI agent entry point (redirects to CLAUDE.md)
├── CLAUDE.md                 # Comprehensive development guidelines and best practices
├── vercel.json               # Vercel deployment config
├── .vercelignore             # Vercel ignore patterns
├── .gitignore                # Comprehensive ignore patterns
└── README.md                 # This file
```

## Quick Start

### Prerequisites

- Node.js 22.0.0 or higher
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
   - Copy your `publishable key` (starts with `sb_publishable_`) - for frontend (optional)
   - Copy your `secret key` (starts with `sb_secret_`) (SUPABASE_SECRET_KEY) - **Keep this secret!**

3. **Add to `.env` file** (see Backend Setup below)

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

# Test against a different API URL
python scripts/test_services.py --api-url https://your-api.railway.app
```

The test script will check:

- API root endpoint connectivity
- Health check endpoint
- Redis connection and operations
- Supabase connection and operations

**Alternative: Manual testing with curl**

```bash
# Test Redis
curl http://localhost:8000/redis/test

# Test Supabase
curl http://localhost:8000/supabase/test

# Check overall health
curl http://localhost:8000/health
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
3. **Set the root directory** to `apps/api` in Railway service settings
4. Railway will automatically detect `railway.json` and `nixpacks.toml` in the service directory
5. **Add Redis plugin**: Click "New" → "Database" → "Add Redis"
   - Railway will automatically set the `REDIS_URL` environment variable
   - The API is configured with Railway-compatible settings (socket family 0 for IPv6/IPv4 dual-stack)
6. **Set Supabase environment variables** in Railway dashboard:
   - `SUPABASE_URL`: Your Supabase project URL
   - `SUPABASE_SECRET_KEY`: Your Supabase secret key (starts with `sb_secret_`) (keep secret!)
7. Set other environment variables (CORS_ORIGINS, etc.)
8. Deploy

**Per-service configuration files in `apps/api/`:**

- `railway.json` - Deployment configuration
- `.railwayignore` - Excludes development files and caches
- `nixpacks.toml` - Build configuration (Node.js 22, npm ci + npm run build)
- `package.json` / `package-lock.json` - Node.js dependencies for this service

The `railway.json` is configured for:

- Automatic builds with NIXPACKS
- Health check endpoint at `/health` (tests both Redis and Supabase)
- Automatic restarts on failure

**Service Configuration:**

- **Redis**: Socket keepalive with TCP settings optimized for Railway
- **Supabase**: Works with any Supabase project (no special Railway plugin needed)
- **Graceful degradation**: API continues to work if services are unavailable
- **Connection retry**: Includes retry strategy with exponential backoff

### Adding More Backend Services

To add additional backend services:

1. Create new service directory under `apps/` (e.g., `apps/worker/`)
2. Add service-specific configuration files:
   - `railway.json` - Deployment config for this service
   - `.railwayignore` - Files to exclude from deployment
   - `nixpacks.toml` - Build configuration (Node.js 22)
   - `package.json` / `package-lock.json` - Node.js dependencies
   - `.env.example` - Environment variable template
3. Create a new Railway service in your project
4. Connect the same repository
5. Set root directory to `apps/worker` in Railway settings
6. Deploy independently

**Example structure for multiple services:**

```
apps/
├── web/              # Next.js frontend
│   ├── package.json
│   └── ...
├── api/              # Express REST API service
│   ├── railway.json
│   ├── package.json
│   └── ...
├── worker/           # Background worker service
│   ├── railway.json
│   ├── package.json
│   └── ...
└── websocket/        # WebSocket service
    ├── railway.json
    ├── package.json
    └── ...
```

Each service is independently deployable with its own configuration and dependencies. Not only does such a structure reduce coupling, but it also speeds up development by allowing you to run one Claude instance per service simultaneously without encountering merge conflicts.

## Environment Variables

### Frontend (`apps/web/.env.local`)

```bash
NEXT_PUBLIC_API_URL=http://localhost:8000
# Add your frontend environment variables here
```

### Backend (`apps/api/.env`)

```bash
# Supabase (required)
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_SECRET_KEY=sb_secret_xxxxxxxxxxxxx

# Redis (required for caching)
REDIS_URL=redis://localhost:6379

# CORS (comma-separated origins)
CORS_ORIGINS=http://localhost:3000,http://localhost:3001

# API Keys (as needed)
ANTHROPIC_API_KEY=your_key_here

# Add your backend environment variables here
```

## Development Guidelines

### AI-Assisted Development

This template includes comprehensive documentation for AI-assisted development:

- **CLAUDE.md**: Comprehensive development guidelines, coding standards, workflows, and best practices
- **AGENTS.md**: Universal entry point for AI agents (redirects to CLAUDE.md)
- **docs/AGENTS_APPENDLOG.md**: Decision log for tracking architectural choices and learnings

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
npm run typecheck    # Type checking for frontend and backend
npm run build        # Build verification
npm run format       # Auto-format code (JS/TS, SQL, shell, markdown)
npm run lint         # Lint checks (JS/TS, shell scripts)
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
- Use `next(error)` to propagate errors to the central error handler

### Testing

Frontend:

```bash
cd apps/web
npm test
```

Backend:

```bash
cd apps/api
npm run type-check
```

## API Health

The Express backend provides the following endpoints:

- Health check: `http://localhost:8000/health`
- Redis test: `http://localhost:8000/redis/test`
- Supabase test: `http://localhost:8000/supabase/test`
- Langfuse test: `http://localhost:8000/langfuse/test`
- AI + trace demo: `POST http://localhost:8000/langfuse/trace-example` (requires `ANTHROPIC_API_KEY`)

## Common Tasks

### Adding a New API Endpoint

1. Create a new router file in `apps/api/src/routes/`
2. Define Zod schemas in `apps/api/src/types/index.ts`
3. Mount it in `apps/api/src/index.ts` with `app.use("/prefix", router)`

### Adding a New Frontend Page

1. Create a new file in `apps/web/app/`
2. Follow Next.js App Router conventions
3. Import and use shared components from `components/`

### Database Migrations

If using Prisma:

```bash
cd apps/api
npx prisma migrate dev --name "description"
npx prisma migrate deploy  # Production
```

If using Supabase migrations directly:

```bash
# Regenerate TypeScript types after schema changes
npx supabase gen types typescript --project-id YOUR_ID > supabase/types.ts
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
