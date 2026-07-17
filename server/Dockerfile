# syntax=docker/dockerfile:1
# Build context is the repository root (see compose.yaml) so that the
# server can access the shared ../maps.json during the build.

FROM node:20-alpine AS base
RUN corepack enable && corepack prepare pnpm@10.15.0 --activate
WORKDIR /app/server

# Install all dependencies and build the server + migrator bundles
FROM base AS build
COPY server/package.json server/pnpm-lock.yaml server/pnpm-workspace.yaml ./
RUN pnpm install --frozen-lockfile
COPY maps.json /app/maps.json
COPY server/ ./
RUN pnpm build

# Install production-only dependencies for the runtime image
FROM base AS prod-deps
COPY server/package.json server/pnpm-lock.yaml server/pnpm-workspace.yaml ./
RUN pnpm install --prod --frozen-lockfile

# Lean runtime image
FROM node:20-alpine AS runtime
WORKDIR /app/server
ENV NODE_ENV=production
COPY --from=prod-deps /app/server/node_modules ./node_modules
COPY --from=build /app/server/dist ./dist
COPY --from=build /app/server/drizzle ./drizzle
COPY server/package.json ./

# Apply committed migrations, then start the server
CMD ["sh", "-c", "node dist/migrate.js && node dist/index.js"]
