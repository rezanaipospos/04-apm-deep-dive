#!/usr/bin/env bash
# Capstone Phase 6 — Mystery Incident.
# Jangan baca isi file ini sebelum incident selesai: jawaban ada di bawah.
#
#   ./chaos/mystery.sh            mulai incident acak
#   ./chaos/mystery.sh 3          mulai skenario tertentu (1–6)
#   ./chaos/mystery.sh status     waktu mulai + durasi + jumlah hint
#   ./chaos/mystery.sh hint       petunjuk bertahap (maks 3)
#   ./chaos/mystery.sh reveal     jawaban + penjelasan (incident tetap aktif)
#   ./chaos/mystery.sh resolve    pulihkan sistem + catat waktu untuk postmortem
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

STATE="$ROOT/chaos/.mystery-state"
TOTAL=6

compose_override() {
  docker compose -f docker-compose.yml -f "chaos/$1" up -d --no-deps --force-recreate "$2" >/dev/null
}

apply_scenario() {
  case "$1" in
    1) compose_override payment-latency.override.yml payment-svc ;;
    2) compose_override payment-500-intermittent.override.yml payment-svc ;;
    3) compose_override layout-badrequest.override.yml layout-svc ;;
    4) docker compose stop layout-svc >/dev/null ;;
    5) compose_override cinema-error500.override.yml cinema-svc ;;
    6) compose_override ui-timeout.override.yml ticketing-ui ;;
  esac
}

report() {
  case "$1" in
    1) echo "Beberapa user mengeluh: proses bayar tiket terasa jauh lebih lama dari biasanya, tapi akhirnya berhasil." ;;
    2) echo "CS menerima beberapa laporan: kadang gagal bayar, tapi setelah dicoba lagi berhasil. Belum ada alert yang dianggap penting." ;;
    3) echo "User melapor: denah kursi tidak muncul setelah memilih jadwal film." ;;
    4) echo "User melapor: denah kursi tidak muncul setelah memilih jadwal film." ;;
    5) echo "User melapor: halaman utama kosong, daftar film tidak tampil." ;;
    6) echo "Banyak user komplain: setelah klik Bayar di web, muncul error dan transaksi tidak selesai." ;;
  esac
}

hint() {
  case "$1-$2" in
    1-1) echo "Journey mana yang terdampak, dan apakah masalahnya availability atau latency? Cek Service Levels / response time checkout." ;;
    1-2) echo "Buka trace checkout yang lambat. Waktu habis di mana: checkout → payment, atau payment → bank?" ;;
    1-3) echo "Bandingkan external duration checkout-svc vs payment-svc. Jika payment → bank normal, masalahnya di dalam payment-svc sendiri. Cek env payment-svc." ;;
    2-1) echo "Error yang jarang tidak terlihat di chart per menit. Coba Errors Inbox dan hitung jumlah error 30 menit terakhir." ;;
    2-2) echo "Hitung burn rate Checkout Availability (query modul 5.3). Lebih dari 1? Lebih dari 13,44?" ;;
    2-3) echo "Errors Inbox: service dan endpoint asal error? Cek env CHAOS_* di service tersebut." ;;
    3-1) echo "Apakah SLO Browse Availability turun? Jika tidak, kenapa?" ;;
    3-2) echo "Buka layout-svc → Transactions / Errors. Status code berapa yang dikirim?" ;;
    3-3) echo "SLI kita menganggap 4xx = request baik (salah user). Apakah 400 ini benar salah user? Cek env layout-svc." ;;
    4-1) echo "Apakah layout-svc masih mengirim data ke New Relic? Lihat throughput-nya." ;;
    4-2) echo "Jalankan docker compose ps. Semua container jalan?" ;;
    4-3) echo "User gagal, tapi kenapa SLO Browse Availability tidak turun? Siapa yang seharusnya mencatat request yang gagal?" ;;
    5-1) echo "Cek alert dan Service Levels: burn rate journey mana yang naik?" ;;
    5-2) echo "Errors Inbox: service dan endpoint mana yang error?" ;;
    5-3) echo "Error ditolak sebelum handler bekerja? Lihat trace (segment handler hilang) dan env cinema-svc." ;;
    6-1) echo "Coba sendiri lewat UI http://localhost:8080 dan buka Network tab di browser. Status code berapa?" ;;
    6-2) echo "Apakah checkout-svc di New Relic mencatat error? Jika backend sehat, siapa yang membalas error ke browser?" ;;
    6-3) echo "docker compose logs ticketing-ui — cari 'upstream timed out'. Bandingkan /etc/nginx/conf.d/default.conf di container dengan apps/ticketing-ui/nginx.conf." ;;
  esac
}

reveal() {
  case "$1" in
    1) cat <<'EOF'
SKENARIO 1 — payment-svc (service internal) lambat 2 detik
Akar masalah : CHAOS_LATENCY_MS=2000 di payment-svc (simulasi deploy baru yang lambat / resource kurang).
Yang terlihat: checkout ±4 detik → SLI Checkout Latency < 3s terbakar (fast burn ±10–15 menit).
               Slow External Call (warning > 3 s) hanya di checkout-svc, TIDAK di payment-svc
               → payment → bank normal, waktu habis di dalam payment-svc.
Pelajaran    : bedakan partner lambat (Skenario B 3.1) vs service internal lambat.
               Internal → tanya tim payment: ada deploy baru? CPU/memori penuh? perlu scale?
EOF
    ;;
    2) cat <<'EOF'
SKENARIO 2 — payment 500 sesekali (5%)
Akar masalah : CHAOS_ERROR_RATE=0.05 di POST /api/payments payment-svc.
Yang terlihat: ±5% checkout gagal → burn rate ≈ 10. Di bawah fast burn (13,44) → tidak ada page.
               Too Many 500 (≥ 5/menit) diam: hanya ±0,4 error per menit.
               Slow burn baru bunyi setelah beberapa jam (rata-rata 6 jam harus > 2,8%).
Pelajaran    : masalah kecil yang terus-menerus tetap menghabiskan budget (burn 10 → habis ±2,8 hari).
               Inilah fungsi slow burn: dibuat tiket dan diperbaiki di jam kerja, bukan page tengah malam.
EOF
    ;;
    3) cat <<'EOF'
SKENARIO 3 — layout-svc membalas HTTP 400 (blind spot 4xx)
Akar masalah : CHAOS_ERROR_STATUS=400 di layout-svc — sistem yang salah, bukan input user.
Yang terlihat: error rate layout-svc 100% di APM (agent menghitung 4xx sebagai error),
               Low Apdex layout-svc bisa bunyi (error = frustrated).
               Tapi Too Many 500 diam (class 400), Too Many Error Logs diam (4xx dicatat level warn),
               dan SLO Browse Availability tetap hijau (good = status < 500).
Pelajaran    : SLI availability sengaja mengabaikan 4xx, jadi 4xx buatan sistem lolos.
               Action item: alert terpisah untuk lonjakan rasio 4xx per endpoint.
EOF
    ;;
    4) cat <<'EOF'
SKENARIO 4 — layout-svc mati (blind spot SLI dari sisi server)
Akar masalah : container layout-svc berhenti (docker compose stop layout-svc).
Yang terlihat: Microservice Down (Zero Throughput) bunyi setelah beberapa menit (jika di-apply di Phase 4).
               nginx membalas 502 ke browser.
               SLO Browse Availability TIDAK turun: layout-svc tidak mengirim transaksi sama sekali,
               jadi valid events hanya berisi cinema-svc yang sehat.
Pelajaran    : SLI dari agent di server buta saat service mati total.
               Butuh pengukuran dari luar: synthetic monitoring, browser (RUM), atau log load balancer.
EOF
    ;;
    5) cat <<'EOF'
SKENARIO 5 — cinema-svc membalas HTTP 500 (pemanasan)
Akar masalah : CHAOS_ERROR_STATUS=500 di cinema-svc, semua endpoint, ditolak sebelum handler.
Yang terlihat: SLO Fast Burn Browse Availability bunyi ±3–5 menit, Too Many 500, Too Many Error Logs.
Pelajaran    : saat alert teknis dan alert SLO bunyi bersamaan, alert SLO memberi tahu dampaknya ke user
               dan berapa cepat budget habis (burn ±500 → budget 28 hari habis ±1,3 jam).
EOF
    ;;
    6) cat <<'EOF'
SKENARIO 6 — timeout nginx terlalu kecil (masalah di depan service)
Akar masalah : perubahan config nginx ticketing-ui: proxy_read_timeout 1s untuk semua upstream.
               Checkout normal ±2 detik → nginx memutus koneksi dan membalas 504 ke browser.
Yang terlihat: semua service sehat di New Relic, tidak ada alert, semua SLO hijau.
               Loadgen memanggil service langsung (tanpa nginx), jadi traffic loadgen tidak terdampak.
               Bukti hanya di browser (504) dan docker compose logs ticketing-ui ("upstream timed out").
Pelajaran    : perubahan konfigurasi infra juga "change" (langkah 3 runbook 3.2).
               Timeout harus lebih besar dari p99 latency upstream.
               Pantau juga di tepi: log nginx ke New Relic, synthetic check, atau browser monitoring.
EOF
    ;;
  esac
}

load_state() {
  if [ ! -f "$STATE" ]; then
    echo "Tidak ada incident aktif. Mulai dengan: ./chaos/mystery.sh"
    exit 1
  fi
  # shellcheck disable=SC1090
  . "$STATE"
}

save_state() {
  cat > "$STATE" <<EOF
SCENARIO=$SCENARIO
INCIDENT_ID=$INCIDENT_ID
STARTED_AT=$STARTED_AT
STARTED_HUMAN="$STARTED_HUMAN"
HINTS=$HINTS
EOF
}

elapsed_min() {
  echo $(( ($(date +%s) - STARTED_AT) / 60 ))
}

start() {
  if [ -f "$STATE" ]; then
    echo "Masih ada incident aktif. Jalankan ./chaos/mystery.sh resolve dulu."
    exit 1
  fi
  SCENARIO="${1:-$(( RANDOM % TOTAL + 1 ))}"
  case "$SCENARIO" in
    [1-6]) ;;
    *) echo "Nomor skenario harus 1–$TOTAL"; exit 1 ;;
  esac

  echo "Menyiapkan incident (reset ke happy flow dulu)..."
  "$ROOT/chaos/disable.sh" >/dev/null
  apply_scenario "$SCENARIO"

  INCIDENT_ID="INC-$(( RANDOM % 9000 + 1000 ))"
  STARTED_AT=$(date +%s)
  STARTED_HUMAN=$(date '+%Y-%m-%d %H:%M:%S')
  HINTS=0
  save_state

  cat <<EOF

==================== $INCIDENT_ID ====================
Waktu laporan : $STARTED_HUMAN
Laporan       : $(report "$SCENARIO")
======================================================

Anda on-call. Deteksi → diagnosis → mitigasi, dan catat waktunya untuk postmortem.
  ./chaos/mystery.sh hint      petunjuk (maks 3, dicatat)
  ./chaos/mystery.sh status    durasi incident
  ./chaos/mystery.sh reveal    jawaban
  ./chaos/mystery.sh resolve   pulihkan sistem
EOF
}

case "${1:-}" in
  ""|[1-6]) start "${1:-}" ;;
  status)
    load_state
    echo "$INCIDENT_ID — mulai $STARTED_HUMAN — berjalan $(elapsed_min) menit — hint dipakai: $HINTS/3"
    ;;
  hint)
    load_state
    if [ "$HINTS" -ge 3 ]; then
      echo "Semua hint sudah dipakai. Gunakan ./chaos/mystery.sh reveal jika masih buntu."
      exit 0
    fi
    HINTS=$((HINTS + 1))
    save_state
    echo "Hint $HINTS/3: $(hint "$SCENARIO" "$HINTS")"
    ;;
  reveal)
    load_state
    echo "$INCIDENT_ID — berjalan $(elapsed_min) menit — hint dipakai: $HINTS/3"
    echo
    reveal "$SCENARIO"
    echo
    echo "Pulihkan dengan: ./chaos/mystery.sh resolve"
    ;;
  resolve)
    load_state
    "$ROOT/chaos/disable.sh" >/dev/null
    RESOLVED_HUMAN=$(date '+%Y-%m-%d %H:%M:%S')
    MIN=$(elapsed_min)
    rm -f "$STATE"
    cat <<EOF
$INCIDENT_ID resolved.
  Mulai    : $STARTED_HUMAN
  Pulih    : $RESOLVED_HUMAN
  Durasi   : $MIN menit
  Hint     : $HINTS/3
Catat angka ini di postmortem (docs/postmortem-template.md).
EOF
    ;;
  *)
    echo "Usage: $0 [1-$TOTAL|status|hint|reveal|resolve]"
    exit 1
    ;;
esac
