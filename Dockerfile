# Etapa 1: traer OpenClaw ya compilado desde la imagen oficial
FROM ghcr.io/openclaw/openclaw:2026.5.2 AS openclaw-build

# Etapa 2: runtime con tu wrapper
FROM node:22-bookworm
ENV NODE_ENV=production

RUN apt-get update \
  && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    ca-certificates \
    tini \
    python3 \
    python3-venv \
  && rm -rf /var/lib/apt/lists/*

# pnpm para `openclaw update`
RUN corepack enable && corepack prepare pnpm@10.23.0 --activate

# Persistencia en el volumen Railway
ENV NPM_CONFIG_PREFIX=/data/npm
ENV NPM_CONFIG_CACHE=/data/npm-cache
ENV PNPM_HOME=/data/pnpm
ENV PNPM_STORE_DIR=/data/pnpm-store
ENV PATH="/data/npm/bin:/data/pnpm:${PATH}"

WORKDIR /app

# Wrapper deps
COPY package.json ./
RUN npm install --omit=dev && npm cache clean --force

# Copiar OpenClaw ya compilado desde la imagen oficial.
# La imagen oficial pone el código en /app dentro de la imagen, pero
# para no romper el wrapper (que también usa /app), lo movemos a /openclaw.
COPY --from=openclaw-build /app /openclaw

# Ejecutable openclaw
RUN printf '%s\n' '#!/usr/bin/env bash' 'exec node /openclaw/dist/entry.js "$@"' > /usr/local/bin/openclaw \
  && chmod +x /usr/local/bin/openclaw

COPY src ./src

EXPOSE 8080
ENTRYPOINT ["tini", "--"]
CMD ["node", "src/server.js"]
