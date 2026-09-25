#!/usr/bin/env bash
# Run loadgen against host-mapped ports (without Docker loadgen service).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export CINEMA_URL="${CINEMA_URL:-http://localhost:8081}"
export LAYOUT_URL="${LAYOUT_URL:-http://localhost:8082}"
export CHECKOUT_URL="${CHECKOUT_URL:-http://localhost:8083}"
export PAYMENT_URL="${PAYMENT_URL:-http://localhost:8084}"
export INTERVAL_SEC="${INTERVAL_SEC:-5}"
exec "$ROOT/traffic/loadgen.sh"
