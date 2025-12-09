# Étape 1: Build
FROM node:lts-alpine AS builder

WORKDIR /app

# Copier uniquement package.json et pnpm-lock.yaml pour cache
COPY package.json pnpm-lock.yaml ./

# Installer pnpm globalement et dépendances
RUN npm install -g pnpm
RUN pnpm install --frozen-lockfile

# Copier le reste du code
COPY . .

# Build Next.js
ENV NEXT_TELEMETRY_DISABLED=1
RUN pnpm run build

# Étape 2: Runtime léger
FROM node:lts-alpine AS runner
WORKDIR /app

# Copier le build optimisé et package.json nécessaire
COPY --from=builder /app/.next ./.next
COPY --from=builder /app/public ./public
COPY --from=builder /app/package.json ./package.json
COPY --from=builder /app/node_modules ./node_modules

# Exposer le port
EXPOSE 3000

# Commande par défaut
CMD ["node", ".next/standalone/server.js"]
