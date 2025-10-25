#!/usr/bin/env bash
set -euo pipefail
pnpm --filter api prisma migrate deploy
