FROM node:26-alpine

WORKDIR /app

# Copy shared directory (needed for TypeScript compilation of shared types)
COPY apps/shared ./apps/shared

# The npm that installs dependencies comes from tools/npm, whose lockfile pins its version and
# sha512 integrity: the base image's own npm may predate engines.npm, which engine-strict refuses.
COPY tools/npm ./tools/npm
RUN cd /app/tools/npm && npm ci --no-audit --no-fund

# Copy API application
COPY apps/api ./apps/api

WORKDIR /app/apps/api

# Install dependencies with the bootstrapped npm
RUN /app/tools/npm/node_modules/.bin/npm ci

# Build TypeScript
RUN /app/tools/npm/node_modules/.bin/npm run build

# Expose port
EXPOSE 8000

# Start the application
CMD ["node", "--expose-gc", "dist/api/src/index.js"]
