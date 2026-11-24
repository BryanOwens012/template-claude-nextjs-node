FROM node:26-alpine

WORKDIR /app

# Copy shared directory (needed for TypeScript compilation of shared types)
COPY apps/shared ./apps/shared

# Copy API application
COPY apps/api ./apps/api

WORKDIR /app/apps/api

# The image bundles an npm older than 12, which engines.npm and engine-strict refuse.
# npm 12 skips dependency install scripts that package.json allowScripts has no decision for.
RUN npm install -g npm@12.2.2

# Install dependencies
RUN npm ci

# Build TypeScript
RUN npm run build

# Expose port
EXPOSE 8000

# Start the application
CMD ["node", "--expose-gc", "dist/api/src/index.js"]
