# NotSphere

NotSphere is a full-stack note taking workspace with realtime collaboration, offline-capable editing, rich formatting, attachments and audio recording. The project is organised as a PNPM workspace with a React + Vite frontend and an Express + Prisma API backend.

## Features

- **Realtime collaboration** powered by Socket.IO for live content, metadata and presence updates.
- **Offline-first editing** – notes are cached in IndexedDB, autosaved locally when the network drops and reconciled with conflict resolution when connectivity returns.
- **Attachments & audio** – upload files to MinIO/S3 via the API and capture PCM audio from the browser.
- **Secure auth** – session cookies with refresh/ access tokens, CSRF protection and Argon2 password hashing.
- **Keyboard shortcuts** – `Ctrl/Cmd+N` new note, `Ctrl/Cmd+S` manual save and `Ctrl/Cmd+K` focus global search.
- **Rich editor** – TipTap with headings, code, tasks, highlights and link support.

## Monorepo structure

```
.
├── apps
│   ├── api       # Express API (TypeScript)
│   └── web       # React web client (Vite + TypeScript)
├── packages
│   └── config    # Shared tsconfig and eslint presets
├── prisma        # Prisma schema
├── infra         # Infrastructure manifests (docker-compose, nginx)
└── scripts       # Automation scripts (dev, build, migrations, seed)
```

## Getting started

### Prerequisites

- [PNPM](https://pnpm.io/) (v8+)
- [Docker](https://www.docker.com/) (for Postgres, MinIO and Mailhog during local development)

### Installation

1. Install dependencies:

   ```bash
   pnpm install
   ```

2. Configure environment files:

   ```bash
   cp apps/api/.env.example apps/api/.env
   cp apps/web/.env.example apps/web/.env
   ```

   Update `DATABASE_URL`, session/JWT secrets, MinIO credentials and optional OAuth keys.

3. Apply database migrations and seed demo data:

   ```bash
   pnpm db:migrate
   pnpm db:seed # optional demo user and onboarding content
   ```

4. Start the full development stack:

   ```bash
   pnpm dev
   ```

   The script spins up Docker services (`infra/docker-compose.yml`), boots the Express API on `http://localhost:3000` and the Vite dev server on `http://localhost:5173`.

5. Navigate to `http://localhost:5173` and sign up – the app seeds a starter group and note for new accounts.

## Scripts

- `pnpm dev` – start Docker services plus API & web dev servers.
- `pnpm lint` – run ESLint for all workspaces.
- `pnpm typecheck` – run TypeScript checks for API and web packages.
- `pnpm test` – run Vitest (frontend) and Jest (backend) suites.
- `pnpm build` – build production bundles for both apps.
- `pnpm db:migrate` / `pnpm db:seed` – run Prisma migrations and seed data.

## Deployment

- `infra/docker-compose.prod.yml` orchestrates the API, web build, Postgres, MinIO and nginx reverse proxy for a container-based deployment.
- `apps/api/Dockerfile` and `apps/web/Dockerfile` create production images suitable for services such as Render, Fly.io or a VM.
- Ensure production environments provide the same secrets as `.env.example` files (database URL, session/JWT secrets, S3/MinIO credentials, CSRF secret and optional OAuth keys). Use secure cookies (`NODE_ENV=production`) and configure `PUBLIC_S3_URL` to the bucket's public endpoint.

## Testing

- Backend: `pnpm --filter api test` (Jest + Supertest with the Prisma test client).
- Frontend: `pnpm --filter web test` (Vitest + React Testing Library).
- Additional checks: `pnpm lint` and `pnpm typecheck`.

## Useful tips

- Use the global shortcuts to move quickly: `Ctrl/Cmd+K` to focus search, `Ctrl/Cmd+N` for a fresh note, `Ctrl/Cmd+S` to force a sync.
- When the network drops the editor switches to **Offline** mode. Changes are cached locally and automatically pushed once connectivity returns; any conflicting server edits will trigger an in-app banner to resolve.
- Attachments are uploaded to the configured S3/MinIO bucket and removed from storage when deleted via the API.
