# Troubleshooting Mode — Chaos Scenarios (Payment)

Prasyarat: happy flow sudah jalan (film → kursi → GoPay/QRIS → proses → sukses) dan aplikasi terlihat di **APM & Services** New Relic.

## Skenario A — Gagal menampilkan saldo user

```bash
./chaos/enable.sh payment-balance-error
# UI: Lanjut ke Pembayaran → gagal load metode/saldo
# atau:
curl -s -o /dev/null -w "%{http_code}\n" "localhost:8084/api/wallet?customer=lab-student"
```

**Expected di New Relic**

- `payment-svc` error rate naik pada transaksi wallet
- Errors inbox / transaction error untuk `GET /api/wallet`
- UI tidak menampilkan saldo GoPay
- Charge `/api/payments` masih sehat (chaos hanya match `/api/wallet`)

**Reset:** `./chaos/disable.sh`

## Skenario B — Latency lambat ke partner (bank)

```bash
./chaos/enable.sh partner-latency
# UI: pilih GoPay/QRIS → Bayar Sekarang (tunggu lebih lama)
```

**Expected di New Relic**

- `bank-svc` response time ~3s+
- Distributed trace: external span payment→bank memakan waktu
- Segment `SimulatePaymentProcessing` + partner latency di waterfall
- Apdex `bank-svc` / downstream `payment-svc` / `checkout-svc` turun
- UI lama di “Pembayaran sedang diproses…”

**Reset:** `./chaos/disable.sh`

## Skenario C — Payment HTTP 500

```bash
./chaos/enable.sh payment-500
# UI: pilih metode → Bayar Sekarang → gagal
```

**Expected di New Relic**

- Status 500 dari `payment-svc` `/api/payments`
- Error rate `payment-svc` naik; Apdex drop
- `checkout-svc` menampilkan error / bad gateway dari payment (external)
- UI gagal bayar; wallet/saldo tetap bisa diload

**Reset:** `./chaos/disable.sh`

## Runbook singkat debugging

1. **APM & Services** / Service map — service mana merah?
2. **Summary** — error rate & response time
3. Satu **distributed trace** / transaction trace — bedakan Datastore vs External vs function segment
4. Cocokkan chaos: `docker compose exec <svc> env | grep CHAOS`
5. `./chaos/disable.sh` → verify recovery di NR
