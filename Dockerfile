# Dockerfile pour l'application Next.js (clinic_app)

# --- Étape 1: Construction (Build) ---
# Utilisation de l'image node:20-alpine pour la construction
FROM node:20-alpine AS builder

# Définir le répertoire de travail
WORKDIR /app

# Copier les fichiers de configuration de dépendances
# Ceci permet d'optimiser le cache Docker en ne réinstallant les dépendances que si ces fichiers changent
COPY package.json pnpm-lock.yaml ./

# Installer pnpm globalement et les dépendances du projet
# Utilisation de --frozen-lockfile pour garantir une installation reproductible
RUN npm install -g pnpm && pnpm install --frozen-lockfile

# Copier le reste du code source
COPY . .

# Construire l'application Next.js
# NEXT_TELEMETRY_DISABLED=1 désactive la télémétrie de Next.js
# output: "standalone" crée un dossier .next/standalone optimisé pour le déploiement Docker
RUN NEXT_TELEMETRY_DISABLED=1 pnpm run build

# --- Étape 2: Exécution (Runtime) ---
# Utilisation d'une image Node.js plus petite pour l'exécution finale (sécurité et taille)
FROM node:20-alpine AS runner

# Définir le répertoire de travail
WORKDIR /app

# Créer un utilisateur non-root pour des raisons de sécurité
RUN addgroup --system --gid 1001 nodejs
RUN adduser --system --uid 1001 nextjs

# Copier les fichiers nécessaires depuis l'étape de construction
# Le dossier standalone contient le serveur Next.js
COPY --from=builder --chown=nextjs:nodejs /app/public ./public
COPY --from=builder --chown=nextjs:nodejs /app/.next/standalone ./
COPY --from=builder --chown=nextjs:nodejs /app/.next/static ./.next/static

# Définir les variables d'environnement
ENV NODE_ENV production
ENV PORT 3000

# Exposer le port
EXPOSE 3000

# Changer l'utilisateur pour l'exécution
USER nextjs

# Commande de démarrage du serveur Next.js standalone
CMD ["node", "server.js"]
