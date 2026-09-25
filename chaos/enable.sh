#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

SCENARIO="${1:-}"
case "$SCENARIO" in
  payment-balance-error)
    docker compose -f docker-compose.yml -f chaos/payment-balance-error.override.yml up -d --no-deps --force-recreate payment-svc
    echo "OK: wallet endpoint returns 500. Expected in NR: error on payment-svc LoadWalletMethods; UI gagal tampilkan saldo."
    ;;
  partner-latency)
    docker compose -f docker-compose.yml -f chaos/partner-latency.override.yml up -d --no-deps --force-recreate bank-svc
    echo "OK: bank-svc latency=3000ms. Expected in NR: slow external span payment→bank; Apdex bank/payment turun."
    ;;
  payment-500)
    docker compose -f docker-compose.yml -f chaos/payment-500.override.yml up -d --no-deps --force-recreate payment-svc
    echo "OK: /api/payments returns 500. Expected in NR: error rate payment-svc; checkout bad gateway; UI gagal bayar."
    ;;
  # legacy aliases
  payment-latency)
    docker compose -f docker-compose.yml -f chaos/partner-latency.override.yml up -d --no-deps --force-recreate bank-svc
    echo "OK (alias): partner-latency via bank-svc."
    ;;
  *)
    echo "Usage: $0 <payment-balance-error|partner-latency|payment-500>"
    exit 1
    ;;
esac
