# Claude Code Instructions

## Project Overview

This is a Next.js + FastAPI template for rapidly spinning up full-stack applications.

**Status**: Template repository (ready for customization)

### Tech Stack
- **Frontend**:
  - Next.js 15+ (App Router, React Server Components)
  - React 19
  - TypeScript 5+
  - Tailwind CSS

- **Backend**:
  - FastAPI (Python 3.11+)
  - Async/await support
  - Auto-generated OpenAPI docs
  - Type safety with Pydantic

- **Deployment**:
  - Frontend: Vercel (auto-configured via vercel.json)
  - Backend: Railway (auto-configured via railway.json)

### Development Philosophy
- **Code Quality First**: Always test after changes, fix all TypeScript/Python errors before committing
- **Modern Syntax**: Use latest ES6+ (TypeScript) and Python 3.11+ features
- **Documentation**: Log significant decisions in docs/AGENTS_APPENDLOG.md (append to that file only; don't read anything in it beyond the final/trailing 20 lines)
- **AI-Assisted**: Leverage AI for rapid development while maintaining high standards

## Development Guidelines

### Code Quality Standards
- **Always test after every change** - Run the application and verify functionality works
- **Build before committing** - Ensure builds pass without errors
- **Fix all type errors** - No ignoring TypeScript or Python type errors
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

### Python Style
- Follow **PEP 8** style guide
- Use **type hints** for all function signatures:
  ```python
  async def get_user(user_id: int) -> User:
      return await db.users.get(user_id)
  ```
- Use **Pydantic models** for request/response validation
- Use **async/await** for I/O operations
- Use **f-strings** for string formatting: `f"Hello {name}"`
- Use **list comprehensions** for simple transformations
- Handle errors explicitly with try/except

### Python Dependency Management

**CRITICAL: Always update requirements.txt after installing packages**

When you install a new Python package:
1. Navigate to the service directory: `cd apps/api`
2. Install the package: `pip install <package-name>`
3. **Immediately** update requirements.txt: `pip freeze > requirements.txt`
4. Test that installation from requirements.txt works: `pip install -r requirements.txt`

**For this monorepo:**
- Each service under `apps/` has its own `requirements.txt`
- `apps/api/requirements.txt` - Python dependencies for the API service
- Each service is independently deployable with its own dependencies
- If you add a new service, create its own requirements.txt

**Example workflow:**
```bash
# Activate venv (from root of monorepo)
source venv/bin/activate  # or: venv\Scripts\activate on Windows

# Navigate to service directory
cd apps/api

# Install new package
pip install <new-package>

# Update service requirements (from within apps/api/)
pip freeze > requirements.txt

# Verify installation works
pip install -r requirements.txt
```

**DO NOT:**
- ❌ Install packages without updating requirements.txt
- ❌ Use outdated or conflicting versions
- ❌ Commit code that requires packages not in requirements.txt
- ❌ Forget to run `pip freeze` from within the service directory

### React Best Practices
- Use **functional components** with hooks only
- Follow React Server Components patterns where possible
- Use `"use client"` directive only when necessary (client-side interactivity required)
- Properly handle loading and error states
- Clean up effects with return functions
- Use proper dependency arrays for hooks

### FastAPI Best Practices
- Use **dependency injection** for shared resources
- Define **Pydantic models** for all request/response bodies
- Use **async route handlers** for I/O operations
- Include proper **status codes** in responses
- Add **comprehensive docstrings** for auto-generated docs
- Handle errors with **HTTPException**

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
apps/frontend/
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
├── main.py              # FastAPI app entry
├── supabase_utils.py    # Supabase helper functions
├── requirements.txt     # Python dependencies for API service
├── railway.json         # Railway deployment config
├── .railwayignore       # Railway ignore patterns
├── nixpacks.toml        # Build configuration
├── .env.example         # Environment variable template
├── routers/             # API route handlers (add as needed)
├── models/              # Pydantic models (add as needed)
├── services/            # Business logic (add as needed)
└── utils/               # Helper functions (add as needed)
```

**Root:**
```
venv/                   # Python virtual environment (gitignored)
vercel.json            # Vercel deployment config for frontend
.vercelignore          # Vercel ignore patterns
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

### Python
- ❌ Don't use blocking I/O in async functions
- ❌ Don't forget type hints
- ❌ Don't ignore Pydantic validation errors
- ❌ Don't use bare except clauses
- ❌ Don't forget to close database connections/sessions

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

### Vercel (Frontend)
The `vercel.json` at the root is configured for:
- Building from `apps/frontend`
- Deploying on pushes to `main` and `develop`
- Ignoring deployments when only backend files change

**Setup:**
1. Connect repository to Vercel
2. Vercel auto-detects `vercel.json`
3. Set environment variables in dashboard
4. Deploy

### Railway (Backend)
Each service under `apps/` can be deployed independently with its own configuration files:
- `railway.json` - Deployment configuration
- `.railwayignore` - Files to exclude from deployment
- `nixpacks.toml` - Build configuration (Python version, dependencies)
- `requirements.txt` - Python dependencies for this service

**Setup for API service:**
1. Create new Railway service
2. Connect repository
3. **Set root directory to `apps/api`** in Railway service settings
4. Railway will detect `railway.json` and `nixpacks.toml` in the service directory
5. Add Redis plugin (Railway will set `REDIS_URL` automatically)
6. Set environment variables (Supabase, CORS, etc.)
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
   - `nixpacks.toml` - Build config
   - `requirements.txt` - Dependencies
   - `.env.example` - Environment template
3. Create new Railway service in your project
4. Connect same repository
5. Set root directory to `apps/worker` in Railway settings
6. Deploy independently

**Example multi-service structure:**
```
apps/
├── api/              # REST API
│   ├── railway.json
│   ├── requirements.txt
│   └── ...
├── worker/           # Background jobs
│   ├── railway.json
│   ├── requirements.txt
│   └── ...
└── websocket/        # WebSocket server
    ├── railway.json
    ├── requirements.txt
    └── ...
```

## Project-Specific Patterns

### Environment Variables

**Frontend** (`apps/frontend/.env`):
```bash
NEXT_PUBLIC_API_URL=http://localhost:8000
# Public vars must be prefixed with NEXT_PUBLIC_
```

**Backend** (`apps/api/.env`):
```bash
DATABASE_URL=postgresql://user:password@localhost:5432/dbname
API_SECRET_KEY=your_secret_here
# No special prefix needed
```

### API Integration Pattern

**Frontend calling Backend:**
```typescript
const response = await fetch(`${process.env.NEXT_PUBLIC_API_URL}/api/endpoint`, {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify(data),
});
const result = await response.json();
```

**Backend API route:**
```python
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel

router = APIRouter()

class UserRequest(BaseModel):
    name: str
    email: str

class UserResponse(BaseModel):
    id: int
    name: str
    email: str

@router.post("/users", response_model=UserResponse)
async def create_user(user: UserRequest):
    # Business logic here
    return UserResponse(id=1, name=user.name, email=user.email)
```

### CORS Configuration

If frontend and backend are on different domains:

```python
from fastapi.middleware.cors import CORSMiddleware

app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:3000", "https://yourapp.vercel.app"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)
```

### Database Integration

**Common patterns:**
- Use SQLAlchemy (async) or Prisma for ORMs
- Use Alembic for migrations
- Store connection string in environment variable
- Use connection pooling for production

### Streaming Responses

**Backend (FastAPI):**
```python
from fastapi.responses import StreamingResponse

async def generate_stream():
    for item in items:
        yield f"data: {json.dumps(item)}\n\n"

@router.get("/stream")
async def stream_endpoint():
    return StreamingResponse(generate_stream(), media_type="text/event-stream")
```

**Frontend (Next.js):**
```typescript
const response = await fetch('/api/stream');
const reader = response.body?.getReader();
while (true) {
  const { done, value } = await reader.read();
  if (done) break;
  // Process stream chunk
}
```

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
- [ ] Dependencies added to requirements.txt (if Python)
- [ ] Package.json updated (if Node.js)

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
