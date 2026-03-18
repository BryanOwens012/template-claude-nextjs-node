# Claude Code Instructions

## Project Overview

This is a Next.js + Node.js template for rapidly spinning up full-stack applications.

**Status**: Template repository (ready for customization)

### Tech Stack

- **Frontend**:
  - Next.js 16+ (App Router, React Server Components)
  - React 19
  - TypeScript 5+
  - Tailwind CSS
  - Radix UI, shadcn/ui

- **Backend**:
  - Express 5 (Node.js 22+)
  - TypeScript with ESM modules ("type": "module")
  - Zod for runtime validation and type safety
  - ioredis for caching
  - Supabase JS client (secret key for server-side operations)
  - Langfuse for LLM observability (optional: prompts, tracing, sessions)

- **Deployment**:
  - Frontend: Vercel (auto-configured via vercel.json)
  - Backend: Railway (auto-configured via railway.json)

### Development Philosophy

- **Code Quality First**: Always test after changes, fix all TypeScript errors before committing
- **Modern Syntax**: Use latest ES6+ and Node.js 22+ features
- **Documentation**: Log significant decisions in docs/AGENTS_APPENDLOG.md (append to that file only; don't read anything in it beyond the final/trailing 20 lines)
- **AI-Assisted**: Leverage AI for rapid development while maintaining high standards

## Development Guidelines

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
- Use async/await instead of promise chains
- Prefer functional array methods: `map`, `filter`, `reduce`

### Express/Node.js Style

- Use **ESM imports** with explicit `.js` extensions in TypeScript source files (e.g., `import { foo } from "@/lib/bar.js"`)
  - TypeScript doesn't rewrite extensions; Node.js ESM requires them
  - Symptom of missing extension: `Error: Cannot find module` at startup
- Define **Zod schemas** for request/response validation, not types (types are inferred from schemas)
- Use `getEnvironment()` from `config/environment.ts` for environment variables (never use `process.env` directly)
- Use `http-errors` package for HTTP errors: `createError(400, "Bad request")`
- Use **async route handlers** with `next(error)` for error propagation
- Handle errors in try/catch and pass to `next()` for central error handler

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

### API Development

- Create routers for logical groupings of endpoints
- Use consistent naming conventions (RESTful when appropriate)
- Version APIs when making breaking changes
- Include health check endpoint at `/health`
- Add comprehensive error handling

### Code Organization

**Frontend:**

```
apps/web/
├── app/                  # Next.js app router
│   ├── page.tsx         # Home page
│   ├── layout.tsx       # Root layout
│   └── api/             # API routes (if needed)
├── components/           # React components
├── lib/                 # Utilities and helpers
└── types/               # TypeScript type definitions
```

**Backend:**

```
apps/api/
├── package.json         # Node.js dependencies and scripts
├── tsconfig.json        # TypeScript configuration (rootDir: ".")
├── src/
│   ├── index.ts         # Express app + route mounting + server start
│   ├── config/
│   │   └── environment.ts        # Zod env validation, lazy singleton, getCorsOrigins()
│   ├── middleware/
│   │   ├── cors.ts              # CORS configuration with localhost passthrough
│   │   └── errorHandler.ts      # Centralized error handling (400s, ZodError, 500)
│   ├── routes/
│   │   ├── index.ts             # GET / — root API info handler
│   │   ├── health.ts            # GET / (mounted at /health)
│   │   ├── redis.ts             # GET /test, POST/GET/DELETE /cache/:key
│   │   └── supabase.ts          # GET / (mounted at /supabase/test)
│   ├── services/
│   │   ├── redis.ts             # initRedis/closeRedis/getRedisClient/isRedisAvailable
│   │   └── supabase.ts          # initSupabase/getSupabaseClient/isSupabaseAvailable
│   └── types/
│       └── index.ts             # Zod schemas + z.infer<> types
├── supabase/
│   ├── types.ts                 # Regenerate with supabase CLI
│   └── migrations/
│       └── .gitkeep
├── railway.json         # Railway deployment config
├── .railwayignore       # Railway ignore patterns
├── nixpacks.toml        # Build configuration (Node.js 22)
└── .env.example         # Environment variable template
```

**Root:**

```
vercel.json            # Vercel deployment config for web app (simplified)
.vercelignore          # Vercel ignore patterns (build only apps/web/)
```

### Testing Workflow

1. Make a change
2. **Test immediately** in the browser/application
3. Verify the specific functionality works
4. Check for unintended side effects
5. Run build/tests to catch errors
6. Only proceed to next change after current one works

### Error Handling

- Handle errors gracefully with try/catch (JS) or try/except (Python)
- Provide meaningful error messages
- Log errors appropriately for debugging
- Don't silently swallow errors
- Return proper HTTP status codes from APIs

### Performance Considerations

- Lazy load components when appropriate
- Memoize expensive computations
- Avoid unnecessary re-renders
- Optimize images and assets
- Monitor bundle size
- Use database indexes for common queries
- Cache API responses when appropriate

### Git Workflow

- Make small, focused commits
- Write clear, descriptive commit messages
- Don't commit untested code
- Keep commits atomic and reversible
- Use conventional commit format when possible

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

## Decision Logging & Meta-Documentation

### Running Logs

- **docs/AGENTS_APPENDLOG.md**: Append-only log of all significant decisions (append to that file only; don't read anything in it beyond the final/trailing 20 lines)
- Log architecture choices, library selections, trade-offs
- Include timestamps in format: `YYYY-MM-DD HH:MM PT` (Pacific Time)
- Never hallucinate timestamps - ask user if current time is unknown

### What to Log

- Framework/library selection decisions
- Architecture changes
- API design choices
- Database schema decisions
- Deployment configuration changes
- Performance optimizations
- Security considerations
- Bug fixes that reveal important learnings

### Log Entry Format

```markdown
## YYYY-MM-DD HH:MM PT - Entry Title

**Type:** [Decision | Implementation | Bug Fix | Refactor]
**Change:** What was changed/decided
**Rationale:** Why this choice was made
**Alternatives Considered:** Other options (if applicable)
**Impact:** Time/complexity/features affected
**Learnings:** Insights or patterns discovered
```

### Holistic Documentation

After appending to AGENTS_APPENDLOG.md:

1. Update README.md with any user-facing changes
2. Incorporate key insights and improved workflows into CLAUDE.md for future reference

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

Each service under `apps/` can be deployed independently with its own configuration files:

- `railway.json` - Deployment configuration
- `.railwayignore` - Files to exclude from deployment
- `nixpacks.toml` - Build configuration (Node.js version, build commands)
- `package.json` and `package-lock.json` - Node.js dependencies for this service

**Setup for API service:**

1. Create new Railway service
2. Connect repository
3. **Set root directory to `apps/api`** in Railway service settings
4. Railway will detect `railway.json` and `nixpacks.toml` in the service directory
5. Add Redis plugin (Railway will set `REDIS_URL` automatically)
6. Set environment variables (SUPABASE_URL, SUPABASE_SECRET_KEY, CORS_ORIGINS)
7. Deploy

**Why per-service configuration:**

- Each service has its own dependencies and configuration
- Services can be deployed and scaled independently
- Easy to add new services without affecting existing ones
- Clear separation of concerns

### Adding More Services

To add additional backend services:

1. Create new service directory under `apps/` (e.g., `apps/worker/`)
2. Add service-specific configuration files:
   - `railway.json` - Deployment config
   - `.railwayignore` - Exclude patterns
   - `nixpacks.toml` - Build config (Node.js 22+)
   - `package.json` and `package-lock.json` - Dependencies
   - `.env.example` - Environment template
3. Create new Railway service in your project
4. Connect same repository
5. Set root directory to `apps/worker` in Railway settings
6. Deploy independently

**Example multi-service structure:**

```
apps/
├── web/              # Next.js frontend
│   ├── package.json
│   └── ...
├── api/              # Express REST API
│   ├── railway.json
│   ├── package.json
│   └── ...
├── worker/           # Background jobs (Node.js + Bull)
│   ├── railway.json
│   ├── package.json
│   └── ...
└── websocket/        # WebSocket server (Node.js)
    ├── railway.json
    ├── package.json
    └── ...
```

## Project-Specific Patterns

### Environment Variables

**Frontend** (`apps/web/.env.local`):

```bash
NEXT_PUBLIC_API_URL=http://localhost:8000
# Public vars must be prefixed with NEXT_PUBLIC_
# Optionally, for direct Supabase client-side calls:
# NEXT_PUBLIC_SUPABASE_URL=https://your-project.supabase.co
# NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY=sb_publishable_xxxxxxxxxxxxx
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

**Frontend calling Backend:**

```typescript
const response = await fetch(`${process.env.NEXT_PUBLIC_API_URL}/api/endpoint`, {
  method: "POST",
  headers: { "Content-Type": "application/json" },
  body: JSON.stringify(data),
});
const result = await response.json();
```

**Backend API route:**

```typescript
import { Router } from "express";
import { z } from "zod";

const router = Router();

const UserRequestSchema = z.object({
  name: z.string(),
  email: z.string().email(),
});

const UserResponseSchema = z.object({
  id: z.number(),
  name: z.string(),
  email: z.string().email(),
});

router.post("/users", async (req, res, next) => {
  try {
    const user = UserRequestSchema.parse(req.body);
    const result = { id: 1, ...user };
    const validated = UserResponseSchema.parse(result);
    res.json(validated);
  } catch (error) {
    next(error);
  }
});

export default router;
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

### Supabase Types

Generate TypeScript types from your Supabase schema:

```bash
npx supabase gen types typescript --project-id YOUR_PROJECT_ID > apps/shared/supabase/types.ts
```

After regenerating, update pgvector fields manually (e.g., embedding fields to `number[] | null`).

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
- Optional — only needed if calling Supabase directly from the browser
- Example: `sb_publishable_xxxxxxxxxxxxx`

**Migration Note:**
Supabase is migrating away from legacy JWT-based keys (old `anon` and `service_role` keys). The new key format started as opt-in in Q1 2025, with full enforcement for new projects starting November 1, 2025. Projects created before then can continue using legacy keys until that date.

### Langfuse Integration (Optional)

[Langfuse](https://langfuse.com/) provides observability for LLM applications: prompt management, tracing, and session tracking.

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

- `src/services/langfuse.ts` — Manages prompts and gracefully degrades if keys are missing
- `src/services/telemetry.ts` — OpenTelemetry SDK with LangfuseSpanProcessor (auto-captures AI SDK spans)
- `GET /langfuse/test` — Verify Langfuse connectivity
- `GET /langfuse/prompts/:name?context=X&query=Y` — Fetch and render prompts with variable substitution (`{{variable}}`)
- `POST /langfuse/trace-example` — Runnable scaffold: Vercel AI SDK + Claude Haiku + tracing + sessions

**AI SDK + Langfuse tracing pattern:**

The template uses [Vercel AI SDK](https://sdk.vercel.ai/) (`ai` + `@ai-sdk/anthropic`) for LLM calls. Both `generateText` and `streamText` are current, non-deprecated APIs:

- `generateText` — non-interactive/agent use; waits for full completion before returning
- `streamText` — interactive/chat use; streams tokens to the client in real time

Tracing flows through OpenTelemetry automatically via `experimental_telemetry` — no manual span creation needed for token counts or model metadata.

**Full pattern with tool call (from `src/routes/langfuse.ts`):**

```typescript
import { generateText, tool, stepCountIs } from "ai";
import { createAnthropic } from "@ai-sdk/anthropic";
import { z } from "zod";
import { startActiveObservation, propagateAttributes } from "@langfuse/tracing";

const anthropic = createAnthropic({ apiKey: env.ANTHROPIC_API_KEY });

// Define a tool — replace execute() with a real API call
const getCurrentWeather = tool({
  description: "Get the current weather for a city.",
  inputSchema: z.object({
    city: z.string().describe("The city to get weather for"),
  }),
  execute: async ({ city }) => ({ city, temperature: 68, condition: "Sunny" }),
});

// sessionId from request body — groups all spans into one Langfuse session
const traceAttrs = sessionId ? { sessionId: String(sessionId) } : {};

await startActiveObservation("my-llm-call", async (span) => {
  span.update({ input: { prompt } }); // annotate the Langfuse observation

  await propagateAttributes(traceAttrs, async () => {
    const result = await generateText({
      model: anthropic("claude-haiku-4-5"),
      prompt,
      tools: { getCurrentWeather },
      // stopWhen enables multi-step: model calls tool → gets result → generates final text
      stopWhen: stepCountIs(3),
      experimental_telemetry: {
        isEnabled: true,
        functionId: "my-llm-call", // label shown in Langfuse
        metadata: { route: "/my-route" },
      },
    });

    generatedText = result.text;
    // result.usage: { inputTokens, outputTokens, totalTokens }
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
// Claude (via @ai-sdk/anthropic — already installed)
anthropic("claude-haiku-4-5"); // fastest, cheapest
anthropic("claude-sonnet-4-6"); // balanced

// OpenAI (install @ai-sdk/openai first)
import { createOpenAI } from "@ai-sdk/openai";
const openai = createOpenAI({ apiKey: env.OPENAI_API_KEY });
openai("gpt-4o-mini");
```

**Streaming (for real-time chat):**

```typescript
import { streamText } from "ai";

const result = streamText({
  model: anthropic("claude-haiku-4-5"),
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
# Requires ANTHROPIC_API_KEY in apps/api/.env
curl -X POST http://localhost:8000/langfuse/trace-example \
  -H "Content-Type: application/json" \
  -d '{"prompt": "What'\''s the weather in Paris?", "sessionId": "my-session-123"}'
# Returns: { text, usage, toolCalls: [{ tool, input, output }], langfuseTraced }
```

All Langfuse features are **optional** and gracefully degrade if not configured.

## Verification Checklist

Before considering any task complete:

### Code Quality

- [ ] Code verified by reading actual files (not assumed)
- [ ] No hallucinated functions, imports, or APIs
- [ ] Code follows style guidelines (arrow functions, type hints, etc.)
- [ ] Types properly defined (TypeScript interfaces, Python type hints)
- [ ] No unused imports or variables
- [ ] Error cases handled appropriately

### Testing

- [ ] Change tested in running application
- [ ] Functionality confirmed to work as expected
- [ ] No console errors or warnings when testing
- [ ] Build passes successfully (frontend and/or backend)
- [ ] All type errors resolved (TypeScript and Python)
- [ ] No regressions in existing functionality

### Documentation

- [ ] Documentation updated if behavior or APIs changed
- [ ] Significant decisions logged in AGENTS_APPENDLOG.md (append to that file only; don't read anything in it beyond the final/trailing 20 lines)
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
   - AGENTS_APPENDLOG.md (last ~100 lines) for recent changes

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
   - Log significant decisions in AGENTS_APPENDLOG.md
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
2. Configure CORS with your actual frontend URL in `apps/api/main.py`
3. Set up database schema (if using Supabase or other database)
4. Add authentication if needed (NextAuth.js, JWT, etc.)
5. Customize API routes for your specific use case

### Documentation Updates

1. Document project-specific patterns in this file (CLAUDE.md)
2. Log initial architecture decisions in `docs/AGENTS_APPENDLOG.md`
3. Update README.md with project-specific setup instructions
4. Add project-specific testing instructions

### Deployment

1. Connect repository to Vercel and Railway
2. Set up environment variables in deployment dashboards
3. Configure custom domains if needed
4. Set up monitoring/logging services if needed
5. Test deployments thoroughly before going live

## Future Enhancements

Common features to add based on project needs:

- Database integration (PostgreSQL, MongoDB, etc.)
- Authentication (NextAuth.js, JWT)
- State management (Zustand, Redux)
- Real-time features (WebSockets, Server-Sent Events)
- File uploads (S3, Cloudinary)
- Background jobs (Celery, BullMQ)
- Caching (Redis)
- Testing (Jest, Pytest, Playwright)
- CI/CD pipelines
- Docker containerization
- Monitoring and logging (Sentry, LogRocket)
