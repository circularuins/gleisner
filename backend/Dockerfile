# syntax=docker/dockerfile:1
FROM node:25.9-bookworm-slim

WORKDIR /app

# Runtime native deps + enable Node-bundled corepack for pnpm.
# Note: we intentionally do NOT `npm i -g corepack@latest` here because
# node:25.9-bookworm-slim already ships corepack along with a yarn shim,
# and `npm i -g` would EEXIST-fail when re-installing the yarn shim.
RUN apt-get update \
  && apt-get install -y --no-install-recommends libatomic1 \
  && rm -rf /var/lib/apt/lists/* \
  && corepack enable

# Install dependencies. pnpm version is resolved from package.json's
# `packageManager` field via corepack, so we avoid mise / aqua-registry
# entirely (which has been broken upstream for pnpm 11.x asset naming).
COPY package.json pnpm-lock.yaml ./
RUN corepack prepare --activate \
  && pnpm install --frozen-lockfile --prefer-offline

# Build (tsc -> dist/)
COPY . .
RUN pnpm build

ENV NODE_ENV=production
EXPOSE 4000
CMD ["node", "dist/index.js"]
