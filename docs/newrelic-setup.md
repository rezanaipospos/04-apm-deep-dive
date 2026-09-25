# New Relic Free — Setup untuk Lab APM

## 1. Buat akun

1. Buka https://newrelic.com/signup
2. Pilih region (US atau EU)
3. Selesaikan onboarding sampai masuk ke New Relic One

## 2. Ambil License Key

1. Klik avatar → **API keys**
2. Buat / salin **Ingest - License key**
3. Jangan commit key ke Git

## 3. Isi `.env` lab

```bash
cd 04-apm-deep-dive
cp .env.example .env
```

```bash
NEW_RELIC_LICENSE_KEY=xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxFFFFFFFFNRAL
```

Setiap service membaca key yang sama; nama aplikasi di NR di-set per container (`NEW_RELIC_APP_NAME` / `ConfigAppName` di kode: `cinema-svc`, `layout-svc`, …).

## 4. Jalankan lab

```bash
docker compose up -d --build
```

Generate traffic otomatis via service \`loadgen\` (sudah ikut \`docker compose up\`), atau UI http://localhost:8080 / \`curl\` (lihat README).

## 5. Verifikasi di New Relic

1. **APM & Services** — 5 aplikasi muncul dalam beberapa menit.
2. Buka `checkout-svc` → **Summary** — latency, throughput, error rate, Apdex.
3. **Distributed tracing** — cari transaksi checkout yang merangkai payment → bank.
4. Waterfall / transaction trace harus memuat:
   - web transaction checkout
   - external call ke `payment-svc`
   - Datastore segment `Mock`
   - function segments (`ValidateSeatsAndAmount`, `AuthorizePayment`, `SimulatePaymentProcessing`, …)
5. **Databases** / **External services** di APM — Datastore Mock + external host partner.
6. Apdex: **Settings → Application** atau chart Summary (T lab = **500ms** di agent).

## 6. Troubleshooting ingest

| Gejala | Cek |
|--------|-----|
| Tidak ada app di NR | License key salah / kosong di `.env` |
| Service Up tapi no data | Generate traffic; tunggu 1–2 menit; `docker compose logs cinema-svc \| grep nragent` |
| Hanya sebagian service | Pastikan semua container `Up` dan env `NEW_RELIC_LICENSE_KEY` ter-inject |
| Trace tidak nyambung antar service | Pastikan `ConfigDistributedTracerEnabled(true)` + HTTP client `newrelic.NewRoundTripper` (sudah di `pkg/nhttp`) |

## Catatan

Lab ini memakai **New Relic Go agent** (bukan OpenTelemetry Collector). Cloud Track modul 3.3 tetap memakai NR di konteks GKE/canary — saling melengkapi.
