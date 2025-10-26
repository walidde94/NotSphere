#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if command -v docker >/dev/null 2>&1; then
  docker compose -f "$ROOT_DIR/infra/docker-compose.yml" up -d
else
  echo "⚠️  Docker is not installed. Database, Mailhog and MinIO will not be available." >&2
fi

pnpm --filter api dev &
API_PID=$!
pnpm --filter web dev &
WEB_PID=$!

cleanup() {
  kill "$API_PID" "$WEB_PID" 2>/dev/null || true
  if command -v docker >/dev/null 2>&1; then
    docker compose -f "$ROOT_DIR/infra/docker-compose.yml" down >/dev/null 2>&1 || true
  fi
}

trap cleanup SIGINT SIGTERM EXIT

wait "$API_PID"
wait "$WEB_PID"
