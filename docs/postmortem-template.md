# Postmortem — [INC-XXXX] [Judul singkat dampak ke user]

> Blameless: tulis **apa** yang terjadi dan **proses apa** yang gagal, bukan **siapa** yang salah.

| | |
|---|---|
| Tanggal | YYYY-MM-DD |
| Penulis | |
| Status | Draft / Final |
| Severity | SEV1 (darurat) / SEV2 / SEV3 |

## 1. Ringkasan

2–3 kalimat: apa yang dialami user, berapa lama, dan apa penyebab utamanya.

## 2. Dampak

| Metrik | Nilai |
|---|---|
| User journey terdampak | Checkout / Browse Film & Kursi / lainnya |
| Durasi dampak | XX menit |
| Request gagal / lambat | ± XXX |
| SLI selama incident | XX% |
| Error budget terbakar | XX% dari budget 28 hari |
| Sisa error budget | XX% |

## 3. Timeline

Gunakan waktu dari `./chaos/mystery.sh status` / `resolve`, halaman alert, dan grafik New Relic.

| Waktu | Kejadian |
|---|---|
| HH:MM | Masalah mulai (perubahan / kejadian pemicu) |
| HH:MM | Alert pertama terbuka: [nama alert] |
| HH:MM | On-call mulai investigasi |
| HH:MM | Akar masalah ditemukan |
| HH:MM | Mitigasi dijalankan |
| HH:MM | Sistem pulih, diverifikasi dengan [query / grafik] |

| Ukuran | Nilai |
|---|---|
| Time to detect (mulai → alert / laporan pertama) | XX menit |
| Time to mitigate (mulai → pulih) | XX menit |

## 4. Akar masalah

Apa yang rusak dan kenapa. Sertakan bukti: trace, query NRQL, log, atau screenshot.

## 5. Deteksi

- Alert apa yang bunyi? Kapan?
- Alert apa yang **seharusnya** bunyi tapi tidak? Kenapa?
- Apakah incident pertama kali diketahui dari alert atau dari laporan user?

## 6. Yang berjalan baik / yang perlu diperbaiki

| Berjalan baik | Perlu diperbaiki |
|---|---|
| | |

## 7. Action items

Setiap item harus spesifik, punya pemilik, dan tenggat. Hindari "lebih hati-hati".

| # | Tindakan | Jenis (Prevent / Detect / Mitigate) | Pemilik | Tenggat |
|---|---|---|---|---|
| 1 | | | | |
| 2 | | | | |

## 8. Error budget policy

Berdasarkan sisa error budget, apa keputusan tim? (lihat modul 5.1)
