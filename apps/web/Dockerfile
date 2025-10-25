FROM node:20-alpine AS deps
WORKDIR /repo
RUN npm install -g pnpm
COPY pnpm-workspace.yaml package.json ./
COPY packages ./packages
COPY apps/web/package.json apps/web/
RUN pnpm install --filter web... --prod=false

FROM node:20-alpine AS build
WORKDIR /repo
RUN npm install -g pnpm
COPY --from=deps /repo/node_modules ./node_modules
COPY pnpm-workspace.yaml package.json ./
COPY packages ./packages
COPY apps/web ./apps/web
RUN pnpm --filter web build

FROM nginx:1.25-alpine
COPY --from=build /repo/apps/web/dist /usr/share/nginx/html
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
