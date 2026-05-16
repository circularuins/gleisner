# syntax=docker/dockerfile:1
FROM node:25.9-bookworm-slim

WORKDIR /app

# Runtime native deps + pnpm. We install pnpm globally via npm rather
# than going through corepack:
# - node:25.9-bookworm-slim does NOT ship the `corepack` CLI (only a
#   yarn shim under /usr/local/bin/yarn). `corepack enable` fails with
#   "corepack: not found".
# - `npm i -g corepack@latest` would re-create the yarn shim and
#   EEXIST-fail, and corepack@0.35 also requires Node >=26.
# Installing pnpm directly side-steps both problems and gives us a
# stable, version-pinned binary.
RUN apt-get update \
  && apt-get install -y --no-install-recommends libatomic1 \
  && rm -rf /var/lib/apt/lists/* \
  && npm i -g pnpm@10.32.1

# Install dependencies (cached layer when lockfile unchanged).
COPY package.json pnpm-lock.yaml ./
RUN pnpm install --frozen-lockfile --prefer-offline

# Build (tsc -> dist/).
COPY . .
RUN pnpm build

ENV NODE_ENV=production
EXPOSE 4000
CMD ["node", "dist/index.js"]
