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

<!-- New log entries go below this line -->
