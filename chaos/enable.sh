#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

SCENARIO="${1:-}"
case "$SCENARIO" in
  payment-balance-error)
    docker compose -f docker-compose.yml -f chaos/payment-balance-error.override.yml up -d --no-deps --force-recreate payment-svc
    echo "OK: wallet endpoint returns 500. Expected in NR: GET /api/wallet error 100% on payment-svc (trace tanpa LoadWalletMethods — ditolak sebelum handler); UI gagal tampilkan saldo."
    ;;
  partner-latency)
    docker compose -f docker-compose.yml -f chaos/partner-latency.override.yml up -d --no-deps --force-recreate bank-svc
    echo "OK: bank-svc latency=30000ms (30s). Expected in NR: slow external span payment→bank; Apdex bank/payment turun."
    ;;
  payment-500)
    docker compose -f docker-compose.yml -f chaos/payment-500.override.yml up -d --no-deps --force-recreate payment-svc
    echo "OK: /api/payments returns 500. Expected in NR: error rate payment-svc; checkout bad gateway; UI gagal bayar."
    ;;
  cinema-500)
    docker compose -f docker-compose.yml -f chaos/cinema-error500.override.yml up -d --no-deps --force-recreate cinema-svc
    echo "OK: cinema-svc returns 500 on all endpoints. Expected in NR: SLI Browse Film & Kursi — Availability turun, burn rate melonjak (Phase 5)."
    ;;
  # legacy aliases
  payment-latency)
    docker compose -f docker-compose.yml -f chaos/partner-latency.override.yml up -d --no-deps --force-recreate bank-svc
    echo "OK (alias): partner-latency via bank-svc."
    ;;
  *)
    echo "Usage: $0 <payment-balance-error|partner-latency|payment-500|cinema-500>"
    exit 1
    ;;
esac
