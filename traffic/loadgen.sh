#!/bin/sh
# Continuous happy-flow traffic for New Relic APM charts.
# Env:
#   CINEMA_URL, LAYOUT_URL, CHECKOUT_URL, PAYMENT_URL
#   INTERVAL_SEC   — pause between full loops (default 5)
#   LIGHT_EVERY    — fire light GETs every N seconds inside wait (default 2)

set -eu

CINEMA_URL="${CINEMA_URL:-http://cinema-svc:8081}"
LAYOUT_URL="${LAYOUT_URL:-http://layout-svc:8082}"
CHECKOUT_URL="${CHECKOUT_URL:-http://checkout-svc:8083}"
PAYMENT_URL="${PAYMENT_URL:-http://payment-svc:8084}"
INTERVAL_SEC="${INTERVAL_SEC:-5}"
LIGHT_EVERY="${LIGHT_EVERY:-2}"

log() { echo "$(date -u +%H:%M:%S) loadgen: $*"; }

wait_ready() {
  i=0
  while [ "$i" -lt 60 ]; do
    if curl -fsS "$CINEMA_URL/healthz" >/dev/null 2>&1 \
      && curl -fsS "$LAYOUT_URL/healthz" >/dev/null 2>&1 \
      && curl -fsS "$CHECKOUT_URL/healthz" >/dev/null 2>&1 \
      && curl -fsS "$PAYMENT_URL/healthz" >/dev/null 2>&1; then
      log "services ready"
      return 0
    fi
    i=$((i + 1))
    sleep 2
  done
  log "timeout waiting for healthz — continuing anyway"
}

light_traffic() {
  curl -fsS "$CINEMA_URL/api/films" >/dev/null || true
  curl -fsS "$LAYOUT_URL/api/layouts/sch-1" >/dev/null || true
  curl -fsS "$PAYMENT_URL/api/wallet?customer=lab-student" >/dev/null || true
}

# Prefer QRIS so GoPay balance is not drained by long-running load.
# Every 10th checkout uses GoPay with a small amount.
checkout_once() {
  n="$1"
  method="qris"
  amount=55000
  seats='["A1"]'
  if [ $((n % 10)) -eq 0 ]; then
    method="gopay"
    amount=45000
    seats='["C1"]'
  elif [ $((n % 3)) -eq 0 ]; then
    amount=110000
    seats='["A1","A2"]'
  fi

  code=$(curl -sS -o /tmp/loadgen-out.json -w "%{http_code}" \
    -X POST "$CHECKOUT_URL/api/checkout" \
    -H 'content-type: application/json' \
    -d "{\"film_id\":\"f-dune2\",\"schedule_id\":\"sch-1\",\"seats\":${seats},\"amount\":${amount},\"customer\":\"lab-student\",\"payment_method\":\"${method}\"}" \
    || echo "000")

  if [ "$code" = "201" ] || [ "$code" = "200" ]; then
    log "checkout ok method=${method} http=${code}"
  else
    log "checkout fail method=${method} http=${code} body=$(head -c 120 /tmp/loadgen-out.json 2>/dev/null || true)"
  fi
}

wait_ready
n=0
log "starting loop interval=${INTERVAL_SEC}s (mostly QRIS; GoPay every 10th)"

while true; do
  n=$((n + 1))
  light_traffic
  checkout_once "$n"

  waited=0
  while [ "$waited" -lt "$INTERVAL_SEC" ]; do
    sleep "$LIGHT_EVERY"
    waited=$((waited + LIGHT_EVERY))
    light_traffic
  done
done
