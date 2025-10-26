FROM node:20-alpine AS deps
WORKDIR /repo
RUN npm install -g pnpm
COPY pnpm-workspace.yaml package.json ./
COPY packages ./packages
COPY apps/api/package.json apps/api/
RUN pnpm install --filter api... --prod=false

FROM node:20-alpine AS build
WORKDIR /repo
RUN npm install -g pnpm
COPY --from=deps /repo/node_modules ./node_modules
COPY pnpm-workspace.yaml package.json ./
COPY packages ./packages
COPY apps/api ./apps/api
COPY prisma ./prisma
RUN pnpm --filter api build

FROM node:20-alpine
WORKDIR /app
ENV NODE_ENV=production
COPY --from=build /repo/apps/api/dist ./dist
COPY --from=deps /repo/apps/api/package.json ./package.json
COPY --from=deps /repo/node_modules ./node_modules
CMD ["node", "dist/server.js"]
