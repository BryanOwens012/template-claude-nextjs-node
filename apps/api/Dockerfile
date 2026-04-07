FROM node:22-alpine

WORKDIR /app

# Copy shared directory (needed for TypeScript compilation of shared types)
COPY apps/shared ./apps/shared

# Copy API application
COPY apps/api ./apps/api

WORKDIR /app/apps/api

# Install dependencies
RUN npm ci

# Build TypeScript
RUN npm run build

# Expose port
EXPOSE 8000

# Start the application
CMD ["node", "--expose-gc", "dist/api/src/index.js"]
