#!/usr/bin/env bash
set -euo pipefail
pnpm --filter api build
pnpm --filter web build
