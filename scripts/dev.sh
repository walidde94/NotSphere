#!/usr/bin/env bash
set -euo pipefail
pnpm --filter api dev &
API_PID=$!
pnpm --filter web dev &
WEB_PID=$!
trap "kill $API_PID $WEB_PID" SIGINT SIGTERM
wait $API_PID
wait $WEB_PID
