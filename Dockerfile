ARG OPENCLAW_VERSION=2026.5.2
FROM ghcr.io/openclaw/openclaw:${OPENCLAW_VERSION} AS openclaw-build

FROM node:22-bookworm
ENV NODE_ENV=production

RUN apt-get update \
  && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    ca-certificates tini python3 python3-venv \
  && rm -rf /var/lib/apt/lists/*

RUN corepack enable && corepack prepare pnpm@10.23.0 --activate

ENV NPM_CONFIG_PREFIX=/data/npm
ENV NPM_CONFIG_CACHE=/data/npm-cache
ENV PNPM_HOME=/data/pnpm
ENV PNPM_STORE_DIR=/data/pnpm-store
ENV PATH="/data/npm/bin:/data/pnpm:${PATH}"

WORKDIR /app

COPY package.json ./
RUN npm install --omit=dev && npm cache clean --force

# Copiar OpenClaw ya compilado desde la imagen oficial
COPY --from=openclaw-build /app /openclaw

# Shim apunta a openclaw.mjs (el entrypoint real de la imagen oficial)
RUN printf '%s\n' '#!/usr/bin/env bash' 'exec node /openclaw/openclaw.mjs "$@"' > /usr/local/bin/openclaw \
  && chmod +x /usr/local/bin/openclaw

COPY src ./src

EXPOSE 8080
ENTRYPOINT ["tini", "--"]
CMD ["node", "src/server.js"]
