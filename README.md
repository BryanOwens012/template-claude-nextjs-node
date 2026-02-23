# Next.js + FastAPI Template

A production-ready template for rapidly spinning up full-stack applications with Next.js frontend and FastAPI backend services.

## Features

- **Modern Frontend**: Next.js 15+ with React 19, TypeScript, and Tailwind CSS
- **Robust Backend**: FastAPI with Python 3.11+, async support, and type safety
- **Supabase Integration**: PostgreSQL database with built-in auth, realtime, and storage
- **Redis Integration**: Built-in caching with Railway-optimized connection settings
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
- **Deployment**: Vercel

### Backend
- **Framework**: FastAPI
- **Language**: Python 3.11+
- **Database**: Supabase (PostgreSQL with auth, realtime, storage)
- **Caching**: Redis (async with Railway-optimized settings)
- **API Documentation**: Auto-generated OpenAPI/Swagger docs
- **Deployment**: Railway (API + Redis plugin)

## Project Structure

```
.
├── apps/
│   ├── frontend/              # Next.js application
│   │   ├── app/              # Next.js app router
│   │   ├── components/       # React components
│   │   ├── lib/              # Utilities and helpers
│   │   ├── package.json
│   │   └── .env.example
│   └── api/                   # FastAPI service
│       ├── main.py           # FastAPI app entry point
│       ├── routers/          # API route handlers
│       ├── models/           # Data models
│       ├── supabase_utils.py # Supabase helper functions
│       ├── requirements.txt  # Python dependencies
│       ├── railway.json      # Railway deployment config
│       ├── .railwayignore    # Railway ignore patterns
│       ├── nixpacks.toml     # Nixpacks build config
│       └── .env.example
├── docs/
│   └── AGENTS_APPENDLOG.md   # Decision log (append-only)
├── scripts/
│   └── test_services.py      # Service connectivity test script
├── venv/                      # Python virtual environment (gitignored)
├── AGENTS.md                  # AI agent entry point (redirects to CLAUDE.md)
├── CLAUDE.md                  # Comprehensive development guidelines and best practices
├── vercel.json               # Vercel deployment config
├── .vercelignore             # Vercel ignore patterns
├── .gitignore                # Comprehensive ignore patterns
└── README.md                 # This file
```

## Quick Start

### Prerequisites

- Node.js 20.17.0 or higher
- Python 3.11 or higher
- npm or yarn
- pip
- [Supabase account](https://supabase.com) (free tier available)

### Supabase Setup

1. **Create a Supabase project**:
   - Go to [https://app.supabase.com](https://app.supabase.com)
   - Click "New Project"
   - Choose an organization, project name, database password, and region

2. **Get your credentials**:
   - Go to Project Settings → API
   - Copy your `Project URL` (SUPABASE_URL)
   - Copy your `anon public` key (SUPABASE_KEY)
   - Copy your `service_role` key (SUPABASE_SERVICE_ROLE_KEY) - **Keep this secret!**

3. **Add to `.env` file** (see Backend Setup below)

### Frontend Setup

```bash
cd apps/frontend
npm install
cp .env.example .env
# Add your environment variables to .env
npm run dev
```

Visit [http://localhost:3000](http://localhost:3000)

### Backend Setup

**Option 1: Root-level venv (Recommended for monorepo development)**
```bash
# From root of monorepo
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate
pip install -r apps/api/requirements.txt

# Set up environment
cp apps/api/.env.example apps/api/.env
# Add your environment variables to apps/api/.env

# Run API
cd apps/api
uvicorn main:app --reload
```

**Option 2: API-level venv (Isolated to API service)**
```bash
cd apps/api
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate
pip install -r requirements.txt
cp .env.example .env
# Add your environment variables to .env
uvicorn main:app --reload
```

API documentation available at [http://localhost:8000/docs](http://localhost:8000/docs)

**Note:** After installing any new Python package, always run `pip freeze > requirements.txt` from within `apps/api/` to keep dependencies up to date.

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
python scripts/test_services.py

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

The `vercel.json` is configured to:
- Build the frontend from `apps/frontend`
- Deploy on pushes to `main` and `develop` branches
- Ignore deployments when only backend files change

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
   - `SUPABASE_KEY`: Your Supabase anon/public key
   - `SUPABASE_SERVICE_ROLE_KEY`: Your Supabase service role key (keep secret!)
7. Set other environment variables (CORS_ORIGINS, etc.)
8. Deploy

**Per-service configuration files in `apps/api/`:**
- `railway.json` - Deployment configuration
- `.railwayignore` - Excludes development files and caches
- `nixpacks.toml` - Build configuration (Python version, dependencies)
- `requirements.txt` - Python dependencies for this service

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
   - `nixpacks.toml` - Build configuration
   - `requirements.txt` - Python dependencies
   - `.env.example` - Environment variable template
3. Create a new Railway service in your project
4. Connect the same repository
5. Set root directory to `apps/worker` in Railway settings
6. Deploy independently

**Example structure for multiple services:**
```
apps/
├── api/              # REST API service
│   ├── railway.json
│   ├── requirements.txt
│   └── ...
├── worker/           # Background worker service
│   ├── railway.json
│   ├── requirements.txt
│   └── ...
└── websocket/        # WebSocket service
    ├── railway.json
    ├── requirements.txt
    └── ...
```

Each service is independently deployable with its own configuration and dependencies. Not only does such a structure reduce coupling, but it also speeds up development by allowing you to run one Claude instance per service simultaneously without encountering merge conflicts.

## Environment Variables

### Frontend (`apps/frontend/.env`)

```bash
NEXT_PUBLIC_API_URL=http://localhost:8000
# Add your frontend environment variables here
```

### Backend (`apps/api/.env`)

```bash
# Supabase (required)
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_KEY=your-anon-public-key-here
SUPABASE_SERVICE_ROLE_KEY=your-service-role-key-here

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

### Code Style

#### JavaScript/TypeScript
- Use arrow functions: `const foo = () => {}`
- Use modern ES6+ syntax (destructuring, spread, optional chaining)
- Prefer `const` over `let`, never use `var`
- Use async/await instead of promise chains

#### Python
- Follow PEP 8 style guide
- Use type hints for all function signatures
- Use async/await for I/O operations in FastAPI
- Use Pydantic models for request/response validation

### Testing

Frontend:
```bash
cd apps/frontend
npm test
```

Backend:
```bash
cd apps/api
pytest
```

## API Documentation

FastAPI automatically generates interactive API documentation:

- Swagger UI: `http://localhost:8000/docs`
- ReDoc: `http://localhost:8000/redoc`
- OpenAPI JSON: `http://localhost:8000/openapi.json`

## Common Tasks

### Adding a New API Endpoint

1. Create a new router in `apps/api/routers/`
2. Import and include it in `main.py`
3. Document with FastAPI decorators and docstrings

### Adding a New Frontend Page

1. Create a new file in `apps/frontend/app/`
2. Follow Next.js App Router conventions
3. Import and use shared components from `components/`

### Database Migrations

If using a database ORM like SQLAlchemy or Prisma:

```bash
# SQLAlchemy (Alembic)
cd apps/api
alembic revision --autogenerate -m "description"
alembic upgrade head

# Prisma
cd apps/frontend
npx prisma migrate dev
```

## Troubleshooting

### Build Errors

- Frontend: Ensure all TypeScript errors are resolved with `npm run build`
- Backend: Check Python version and dependencies with `pip list`

### CORS Issues

If you encounter CORS errors, ensure your FastAPI app includes CORS middleware:

```python
from fastapi.middleware.cors import CORSMiddleware

app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:3000"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)
```

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
