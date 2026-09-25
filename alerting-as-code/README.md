# Alerting as Code (New Relic + Terragrunt)

Provisioning **alert policy**, **NRQL conditions**, dan opsional **Slack channel + workflow** untuk lab ticketing APM.

> **Catatan:** untuk production / kerja tim, state Terraform lebih baik disimpan di cloud storage (GCP, AWS, dan sejenisnya). Di lab ini ikuti perintah apply di bawah — state dikelola otomatis di mesin Anda.

## Prasyarat

- Terraform `~> 1.0` dan [Terragrunt](https://terragrunt.gruntwork.io/)
- Akun New Relic (sama dengan lab APM)
- **User API key** (bukan ingest license): New Relic → API keys → User key (`NRAK-...`)
- Account ID numerik (API keys / Account settings)

## Kredensial (environment)

```bash
cd 04-apm-deep-dive/alerting-as-code

export NEW_RELIC_ACCOUNT_ID=1234567
export NEW_RELIC_USER_API_KEY=NRAK-xxxxxxxx
export NEW_RELIC_REGION=US   # atau EU

# Opsional — hanya jika Anda apply Slack channel + workflow
export NEW_RELIC_SLACK_DESTINATION_ID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
export NEW_RELIC_SLACK_CHANNEL_ID=C0123456789
```

Atau salin `env.example` → isi, lalu `set -a; source .env.alerting; set +a`.

## Struktur

```text
alerting-as-code/
├── terragrunt.hcl
├── src/                        # modul Terraform reusable
│   ├── alert-policy/
│   ├── alert-condition/nrql/
│   ├── alert-channel/
│   └── alert-workflow/
└── newrelic/a-commons/         # stack lab ticketing
    ├── policies/service-anomaly/
    ├── conditions/service/{apdex,responsecode-500,healtcheck,level-error}/
    ├── channels/slack/911-incident/   # opsional
    └── workflows/service-workflow/    # opsional
```

## Apply urutan (wajib)

Policy dulu, lalu conditions (dependency Terragrunt):

```bash
cd newrelic/a-commons/policies/service-anomaly
terragrunt init
terragrunt apply -auto-approve

cd ../../conditions/service/apdex
terragrunt apply -auto-approve

cd ../responsecode-500
terragrunt apply -auto-approve

cd ../healtcheck
terragrunt apply -auto-approve

cd ../level-error
terragrunt apply -auto-approve
```

Verifikasi di New Relic UI: **Alerts & AI → Alert Conditions / Policies** — policy **Ticketing Lab — Service Anomaly** + 4 conditions.

## Slack + workflow (opsional)

Butuh Destination Slack di New Relic (Integrations → Destinations). Setelah env Slack di-set:

```bash
cd ../../channels/slack/911-incident
terragrunt apply -auto-approve

cd ../../../workflows/service-workflow
terragrunt apply -auto-approve
```

Tanpa Slack, policy + conditions saja sudah cukup untuk Phase 5 course.

## Trigger alert di lab

```bash
cd 04-apm-deep-dive
./chaos/enable.sh payment-500
# tunggu beberapa menit — condition "Too Many Response Code 500" dapat open
./chaos/disable.sh
```

## Destroy

Jalankan `terragrunt destroy -auto-approve` dari tiap folder yang pernah di-apply (conditions → policy; workflow → channel), atau hapus resource di NR UI.

## Catatan

- Modul `src/entity-tags` dan `src/alert-muting` tidak dipakai di path `a-commons` lab ini.
- Ingest license key (`.env` lab Docker) **tidak** dipakai Terragrunt — bedakan dari User API key.
