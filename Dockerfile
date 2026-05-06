WORKDIR /openclaw

# Variables de entorno que ganan sobre cualquier archivo de configuración
ENV NPM_CONFIG_MINIMUM_RELEASE_AGE=0
ENV PNPM_CONFIG_MINIMUM_RELEASE_AGE=0
ENV COREPACK_ENABLE_STRICT=0

ARG OPENCLAW_GIT_REF=v2026.3.8
RUN git clone --depth 1 --branch "${OPENCLAW_GIT_REF}" https://github.com/openclaw/openclaw.git .

# Patch: relax version requirements para extensiones
RUN set -eux; \
  find ./extensions -name 'package.json' -type f | while read -r f; do \
    sed -i -E 's/"openclaw"[[:space:]]*:[[:space:]]*">=[^"]+"/"openclaw": "*"/g' "$f"; \
    sed -i -E 's/"openclaw"[[:space:]]*:[[:space:]]*"workspace:[^"]+"/"openclaw": "*"/g' "$f"; \
  done

# NO sobreescribir pnpm-workspace.yaml — solo eliminar la línea problemática si existe
RUN if [ -f pnpm-workspace.yaml ]; then \
      sed -i '/minimumReleaseAge/Id' pnpm-workspace.yaml; \
    fi

# Limpiar minimumReleaseAge de TODOS los package.json del monorepo, no solo el raíz
RUN find . -name 'package.json' -not -path '*/node_modules/*' -type f | while read -r f; do \
      node -e "try{const fs=require('fs');const p=JSON.parse(fs.readFileSync('$f','utf8'));let changed=false;if(p.pnpm&&p.pnpm.minimumReleaseAge!==undefined){delete p.pnpm.minimumReleaseAge;changed=true;}if(p.pnpm&&p.pnpm.minimumReleaseAgeExclude!==undefined){delete p.pnpm.minimumReleaseAgeExclude;changed=true;}if(changed)fs.writeFileSync('$f',JSON.stringify(p,null,2));}catch(e){}"; \
    done

# Limpieza de .npmrc y .pnpmrc en raíz y subpaquetes
RUN find . -name '.npmrc' -not -path '*/node_modules/*' -type f -exec sed -i '/minimumReleaseAge/Id' {} \; || true
RUN find . -name '.pnpmrc' -not -path '*/node_modules/*' -type f -exec sed -i '/minimumReleaseAge/Id' {} \; || true

# Diagnóstico — DEJA ESTAS LÍNEAS la primera vez que rebuildeas
RUN echo "=== pnpm config list ===" && pnpm config list 2>&1 | grep -i release || echo "no release-age in pnpm config"
RUN echo "=== env vars ===" && env | grep -iE 'release|npm_config|pnpm' || echo "no relevant env"
RUN echo "=== pnpm-workspace.yaml ===" && cat pnpm-workspace.yaml
RUN echo "=== root package.json pnpm key ===" && node -e "const p=require('./package.json');console.log(JSON.stringify(p.pnpm||{},null,2))"
RUN echo "=== files con minimumReleaseAge ===" && grep -rln "minimumReleaseAge" . --include='*.yaml' --include='*.yml' --include='*.json' --include='.npmrc' --include='.pnpmrc' 2>/dev/null | grep -v node_modules || echo "ninguno"

# Install con flag explícito como red de seguridad final
RUN pnpm install --no-frozen-lockfile --config.minimum-release-age=0

RUN pnpm build
