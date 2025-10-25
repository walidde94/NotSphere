# NotSphere

NotSphere is a full-stack note taking workspace with realtime collaboration, attachments and audio recording. The project is organised as a PNPM workspace with React + Vite on the frontend and an Express + Prisma API.

## Monorepo structure

```
.
├── apps
│   ├── api       # Express API (TypeScript)
│   └── web       # React web client (Vite + TypeScript)
├── packages
│   └── config    # Shared tsconfig and eslint presets
├── prisma        # Prisma schema
├── infra         # Infrastructure manifests (docker-compose, nginx) [todo]
└── scripts       # Automation scripts (dev, build, migrations, seed)
```

## Getting started

1. Install dependencies using PNPM:

   ```bash
   pnpm install
   ```

2. Configure environment files:

   - Copy `apps/api/.env.example` to `apps/api/.env` and update secrets/database details.
   - Copy `apps/web/.env.example` to `apps/web/.env` if you want to override defaults.

3. Apply database migrations:

   ```bash
   pnpm db:migrate
   ```

4. Seed demo data (optional):

   ```bash
   pnpm db:seed
   ```

5. Run the development servers:

   ```bash
   pnpm dev
   ```

   The API runs on http://localhost:3000 and the Vite dev server on http://localhost:5173.

## Scripts

- `pnpm lint` – run ESLint for all workspaces.
- `pnpm typecheck` – run TypeScript checks for the API and web app.
- `pnpm test` – run unit tests (Vitest + Jest).
- `pnpm build` – build the production bundles.

## Deployment

The repository includes scripts and configuration stubs for containerised deployment. Provide environment variables for PostgreSQL, JWT/session secrets and object storage before running production builds.

## Testing

Frontend tests run with Vitest and React Testing Library. Backend tests run with Jest and ts-jest.
