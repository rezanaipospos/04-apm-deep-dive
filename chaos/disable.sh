#!/usr/bin/env bash
# Reset all services to happy-flow (no chaos env).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
docker compose up -d --force-recreate cinema-svc layout-svc checkout-svc payment-svc bank-svc
echo "OK: chaos disabled — happy flow restored."
