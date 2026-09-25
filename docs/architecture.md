# Architecture — APM Deep Dive Lab

## Components

| Component | Role |
|-----------|------|
| ticketing-ui | Vite + nginx reverse proxy ke API |
| cinema-svc | Katalog film & jadwal |
| layout-svc | Layout kursi per jadwal |
| checkout-svc | Orkestrasi transaksi + panggil payment |
| payment-svc | Wallet (GoPay/QRIS) + authorize + panggil bank |
| bank-svc | Mock payment partner / gateway |

## Observability

Setiap Go service menjalankan **New Relic Go agent** (`pkg/nragent`):

- Web transactions via `nrchi` middleware
- Datastore segments via `pkg/mockdb` (`db.system` product = Mock)
- External segments via `newrelic.NewRoundTripper` (`pkg/nhttp`)
- Function segments + `NoticeError` di block bisnis
- Distributed tracing antar service (header propagation)

Tidak ada OTel Collector di lab ini — agent mengirim langsung ke New Relic.

## Happy path

```text
UI → films → layouts → wallet methods → checkout
  → payment (processing wait) → bank → PAID
```

## Chaos

Env flags di-inject lewat compose override (`chaos/*.override.yml`):

- `CHAOS_MATCH_PATH` — batasi chaos ke path tertentu
- `CHAOS_LATENCY_MS` / `CHAOS_ERROR_STATUS` / `CHAOS_ERROR_RATE`
