# Étape 1 : Build
FROM node:20-alpine AS builder

WORKDIR /app

# Copier uniquement package.json et pnpm-lock.yaml pour optimiser le cache
COPY package.json pnpm-lock.yaml ./

# Installer pnpm et dépendances
RUN npm install -g pnpm
RUN pnpm install --frozen-lockfile

# Copier le reste du code
COPY . .

# Build Next.js (standalone)
ENV NEXT_TELEMETRY_DISABLED=1
RUN pnpm run build

# Étape 2 : Runtime
FROM node:20-alpine AS runner

WORKDIR /app

# Créer un utilisateur non-root
RUN addgroup --system --gid 1001 nodejs
RUN adduser --system --uid 1001 nextjs

# Copier les fichiers nécessaires depuis le builder
COPY --from=builder --chown=nextjs:nodejs /app/.next/standalone ./
COPY --from=builder --chown=nextjs:nodejs /app/.next/static ./.next/static
COPY --from=builder --chown=nextjs:nodejs /app/public ./public
COPY --from=builder --chown=nextjs:nodejs /app/node_modules ./node_modules
COPY --from=builder --chown=nextjs:nodejs /app/package.json ./package.json

# Variables d'environnement (format recommandé)
ENV NODE_ENV=production
ENV PORT=3000

EXPOSE 3000

USER nextjs

CMD ["node", "server.js"]
