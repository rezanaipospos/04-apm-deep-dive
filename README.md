# 04 — Deep Dive: Application Monitoring Performance (APM)

Lab ticketing online ala **mTix**: Vite UI + 5 microservice Go di Docker, instrumentasi **New Relic Go agent**, ingest langsung ke **New Relic Free**. Fokus monitoring & debugging — **tanpa instal database nyata** (mock DB + Datastore segment).

## Arsitektur

```text
Browser (ticketing-ui :8080)
  → cinema-svc   :8081   film + jadwal + bioskop
  → layout-svc   :8082   layout kursi
  → payment-svc  :8084   wallet (GoPay saldo) + charge
  → checkout-svc :8083   transaksi → payment (gopay|qris)
       → payment-svc → bank-svc :8085 (mock partner gateway)

Setiap Go service → New Relic Go agent → New Relic APM
```

## Prasyarat

- Docker + Docker Compose
- Akun [New Relic Free](https://newrelic.com/signup)
- License key (Ingest — License key) dari New Relic

## Quick start

```bash
cd 04-apm-deep-dive
cp .env.example .env
# edit NEW_RELIC_LICENSE_KEY=...

docker compose up -d --build
```

UI: http://localhost:8080  

**Traffic otomatis:** service `loadgen` langsung jalan (loop film → layout → wallet → checkout). Tidak perlu klik UI agar chart New Relic terisi.

```bash
docker compose logs -f loadgen          # lihat request
docker compose stop loadgen             # hentikan traffic
# atur kecepatan di .env: LOADGEN_INTERVAL_SEC=5
```

Atau dari host: `./traffic/run-local.sh`

Happy flow manual di UI: pilih film → kursi → **GoPay / QRIS** → tunggu “sedang diproses” → sukses.

API health:

```bash
curl -s localhost:8081/healthz
curl -s localhost:8082/healthz
curl -s localhost:8083/healthz
curl -s localhost:8084/healthz
curl -s "localhost:8084/api/wallet?customer=lab-student"
```

Happy flow checkout (API):

```bash
curl -s -X POST localhost:8083/api/checkout \
  -H 'content-type: application/json' \
  -d '{"film_id":"f-dune2","schedule_id":"sch-1","seats":["A1","A2"],"amount":110000,"customer":"lab-student","payment_method":"gopay"}'
```

## Chaos (troubleshooting)

```bash
./chaos/enable.sh payment-balance-error   # gagal load saldo
./chaos/enable.sh partner-latency         # bank lambat ~3s
./chaos/enable.sh payment-500             # charge 500
./chaos/disable.sh
```

Lihat `docs/troubleshooting.md`.

Di New Relic: **APM & Services** → cari `cinema-svc`, `layout-svc`, `checkout-svc`, `payment-svc`, `bank-svc`. Buka satu transaction / distributed trace checkout — harus terlihat segment HTTP, **Datastore (Mock)**, external bank, dan function segments (`AuthorizePayment`, `SimulatePaymentProcessing`, dll.).

## Metrics & Apdex

New Relic Go agent mengirim golden signals APM secara native:

- Response time / throughput / error rate
- Apdex (T default lab **500ms**, via agent config)
- Transaction traces + distributed tracing antar service

## Alerting as Code (Phase 5)

Policy + NRQL conditions via **Terragrunt**:

```bash
cd alerting-as-code
cp env.example .env.alerting   # User API key NRAK-... + account id
set -a && source .env.alerting && set +a
# lihat alerting-as-code/README.md — apply policy lalu conditions
```

> **Catatan:** untuk production / kerja tim, state Terraform lebih baik disimpan di cloud storage (GCP, AWS, dll.).

## Struktur

```text
04-apm-deep-dive/
├── docker-compose.yml
├── apps/ticketing-ui/
├── services/{cinema,layout,checkout,payment,bank}/
├── services/pkg/{nragent,applog,chaos,mockdb,nhttp,httpserver}/
├── alerting-as-code/          # Terragrunt New Relic alerts
├── chaos/
├── traffic/
└── docs/
```

Logging & correlation: lihat `docs/logging.md`.  
Contoh instrumentasi lengkap (metrics + segments) untuk ditiru di kode Anda: `docs/instrumentation-go-example.md` (Modul 2.4 di platform).

## Teardown

```bash
docker compose down -v
```
