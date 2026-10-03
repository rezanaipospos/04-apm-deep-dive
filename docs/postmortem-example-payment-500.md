# Postmortem — INC-4821 Checkout gagal 100% selama 14 menit

> Contoh postmortem dari Skenario C modul 3.1 (`./chaos/enable.sh payment-500`). Angka disesuaikan dengan traffic loadgen lab.

| | |
|---|---|
| Tanggal | 2026-10-03 |
| Penulis | On-call lab |
| Status | Final |
| Severity | SEV1 — journey utama (bayar tiket) gagal total |

## 1. Ringkasan

Selama 14 menit, semua pembayaran tiket gagal dengan error di UI. `payment-svc` membalas HTTP 500 untuk setiap `POST /api/payments` karena konfigurasi environment yang memaksa error, sehingga `checkout-svc` membalas 502 ke user. Sistem pulih setelah konfigurasi `payment-svc` dikembalikan ke baseline.

## 2. Dampak

| Metrik | Nilai |
|---|---|
| User journey terdampak | Checkout (bayar tiket). Browse film & kursi tidak terdampak |
| Durasi dampak | 14 menit (10:00–10:14) |
| Request gagal | ± 140 checkout (± 10 per menit) |
| SLI Checkout Availability selama incident | 0% |
| Error budget terbakar | 140 / 1.512 ≈ **9,3%** dari budget 28 hari |
| Sisa error budget | 88% (sebelumnya 97%) |

## 3. Timeline

| Waktu | Kejadian |
|---|---|
| 10:00 | `payment-svc` di-recreate dengan env `CHAOS_MATCH_PATH=/api/payments`, `CHAOS_ERROR_STATUS=500` |
| 10:03 | Alert **Too Many Response Code 500** terbuka (facet `payment-svc` · `POST /api/payments`) |
| 10:06 | Alert **SLO Fast Burn — Checkout Availability** terbuka (bad events > 6,72% dalam 1 jam) |
| 10:08 | On-call mulai investigasi (alert pertama tidak langsung dilihat — tidak ada notifikasi Slack) |
| 10:10 | Errors Inbox: 500 di `payment-svc`, trace tanpa segment handler → ditolak sebelum kode bisnis jalan |
| 10:11 | `docker compose exec payment-svc env | grep CHAOS` → env chaos aktif |
| 10:12 | Mitigasi: `./chaos/disable.sh` |
| 10:14 | Checkout sukses kembali, diverifikasi dengan query burn rate = 0 per menit |
| 11:05 | Incident SLO Fast Burn tertutup otomatis (jendela 1 jam bersih dari kegagalan) |

| Ukuran | Nilai |
|---|---|
| Time to detect | 3 menit (alert teknis), 6 menit (alert SLO) |
| Time to mitigate | 14 menit |

## 4. Akar masalah

`payment-svc` dijalankan dengan environment yang membuat middleware chaos menolak setiap `POST /api/payments` dengan HTTP 500 **sebelum** handler berjalan. `checkout-svc` meneruskan kegagalan itu sebagai 502.

Bukti:

```sql
SELECT count(*) FROM TransactionError
WHERE appName = 'payment-svc' FACET transactionUiName SINCE 30 minutes ago
```

Di dunia nyata, padanannya adalah perubahan konfigurasi (feature flag, env, secret) yang ikut ter-deploy tanpa review.

## 5. Deteksi

- **Bunyi:** Too Many 500 (3 menit) dan SLO Fast Burn (6 menit).
- **Masalah:** alert terbuka di New Relic, tapi tidak ada notifikasi ke on-call. 5 menit hilang sebelum ada yang melihat.
- Incident diketahui dari alert, bukan dari laporan user.

## 6. Yang berjalan baik / yang perlu diperbaiki

| Berjalan baik | Perlu diperbaiki |
|---|---|
| Alert teknis menunjuk service + endpoint yang tepat | Tidak ada notifikasi Slack untuk policy SLO Burn Rate |
| Trace memperlihatkan request ditolak sebelum handler | Perubahan env payment-svc tidak lewat review |
| Runbook 3.2 mempercepat diagnosis | Belum ada link runbook di deskripsi alert SLO |

## 7. Action items

| # | Tindakan | Jenis | Pemilik | Tenggat |
|---|---|---|---|---|
| 1 | Hubungkan policy SLO Burn Rate ke Slack workflow (modul 4.2) | Detect | SRE | 2026-10-05 |
| 2 | Wajibkan perubahan env/config service lewat PR + review | Prevent | Platform | 2026-10-10 |
| 3 | Isi `runbook_url` di condition SLO Fast Burn dengan langkah diagnosis payment | Mitigate | Tim payment | 2026-10-07 |

## 8. Error budget policy

Sisa budget 88% (> 50%) → deploy fitur tetap normal. Action item #2 tetap diprioritaskan di sprint ini karena penyebabnya proses, bukan kode.
