# Logging & Trace Correlation (Production Practice)

## Apa yang diimplementasikan

Setiap Go service memakai `pkg/applog`:

| Praktik | Implementasi |
|---------|----------------|
| Structured JSON logs (stdout) | `log/slog` JSON → cocok Docker/K8s log shipper |
| Correlation IDs | `request.id` (header `X-Request-Id`), `trace.id`, `span.id` |
| Business keys | `transaction.id`, `customer.id`, `payment.method`, … |
| NR Logs in context | `txn.RecordLog` + agent log forwarding |
| Response headers | `X-Request-Id`, `X-Trace-Id` |
| Checkout body | field `trace_id` pada response sukses |

## Kebijakan apa yang di-log

**Hanya event transaksi bisnis + error/warn** — bukan access log setiap GET films/layout/wallet.

| Level | Contoh |
|-------|--------|
| Info (transaksi) | `checkout_started`, `checkout_completed`, `payment_authorize_started`, `payment_authorize_completed` |
| Warn / Error | validasi gagal, payment/bank gagal, HTTP 4xx/5xx, saldo tidak cukup |

Loadgen yang memanggil `/api/films` dll. **tidak** menghasilkan noise log sukses.

## Debug runtut: mana yang dipakai?

**Respon lambat untuk checkout transaksi tertentu — normalnya pakai apa?**

Keduanya saling melengkapi; **entry point terbaik = Distributed Trace**, bukan log mentah.

```text
1. Dapatkan kunci bisnis
   - transaction.id  (TX-…) dari response API / UI
   - atau customer.id
   - atau header X-Trace-Id / field trace_id

2. New Relic → APM → Distributed tracing
   Filter / search attribute: transaction.id = TX-…
   → buka waterfall: segment mana yang mahal? (SimulatePaymentProcessing, external bank, datastore)

3. Dari trace yang sama → tab Logs (logs in context)
   → lihat log berurutan checkout_started → payment_authorize_* → checkout_completed
   semuanya share trace.id + transaction.id yang sama
```

| Pertanyaan | Alat utama |
|------------|------------|
| *Kenapa request ini 2.5 detik?* | **Trace waterfall** (segment timing) |
| *Apa yang terjadi step-by-step / error message?* | **Logs** filter `transaction.id` atau `trace.id` |
| *Customer X sering lambat?* | NR query/filter `customer.id` di traces + logs |
| *Error rate naik?* | APM Summary + Errors inbox |

**Nomor transaksi (`TX-…`) ≠ Trace ID.**  
`transaction.id` = ID bisnis ticketing.  
`trace.id` = ID distributed tracing New Relic.  
Lab menempelkan keduanya di attribute + log supaya bisa join.

Response time checkout ~2s di happy path **normal** di lab ini karena sengaja ada segment `SimulatePaymentProcessing` (~1.8s). Chaos `partner-latency` menambah delay di bank.

## Cara lihat log lokal (runtut)

```bash
# Semua service, JSON satu baris per event
docker compose logs -f checkout-svc payment-svc bank-svc

# Filter satu transaksi bisnis
docker compose logs checkout-svc payment-svc | grep 'TX-1789'

# Filter satu trace
docker compose logs checkout-svc payment-svc | grep '"trace.id":"...'
```

## New Relic Logs

1. **Logs** → filter `transaction.id:`TX-…`` atau `trace.id:…`
2. Dari APM trace → **See logs** / correlated logs
3. Pastikan forwarding on (default lab): `NEW_RELIC_APPLICATION_LOGGING_FORWARDING_ENABLED=true`

## Env

| Variable | Default | Fungsi |
|----------|---------|--------|
| `LOG_LEVEL` | `info` | `debug` / `info` / `warn` / `error` |
| `NEW_RELIC_APPLICATION_LOGGING_FORWARDING_ENABLED` | `true` | Kirim log ke NR via agent |
