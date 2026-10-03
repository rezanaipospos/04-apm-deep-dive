include {
  path = find_in_parent_folders()
}

terraform {
  source = "../../../../../src/alert-condition/nrql/"
}

dependency "slo-burn-rate" {
  config_path = "../../../policies/slo-burn-rate"
}

dependency "sli" {
  config_path = "../../../service-levels/checkout-availability"
}

locals {
  # Slow burn (Google SRE): 5% budget habis dalam 6 jam.
  # burn rate = (0.05 * 28 hari * 24 jam) / 6 jam = 5.6
  burn_rate      = 5.6
  window_seconds = 21600
}

inputs = {
  alert_policy_id       = dependency.slo-burn-rate.outputs.alert_policy_id
  alert_conditions_name = "SLO Slow Burn — Checkout Availability"
  alert_conditions_enable = true
  alert_conditions_desc = <<-EOF
    *Arti:* error budget Checkout Availability terbakar >= 5.6x lebih cepat dari normal
    selama 6 jam (5% budget). Bukan darurat malam ini, tapi budget habis ~5 hari jika dibiarkan.
    *What to Do:*
    1. Buat tiket / prioritaskan di sprint (bukan page on-call)
    2. Cek tren error rate checkout 6–24 jam terakhir: deploy baru? partner tidak stabil?
    3. Cek sisa error budget di Service Levels → terapkan error budget policy tim
  EOF
  alert_conditions_runbook_url = "#"
  alert_conditions_query       = <<-EOF
    FROM Metric SELECT 100 - clamp_max(sum(newrelic.sli.good) / sum(newrelic.sli.valid) * 100, 100) AS 'Bad events (%)'
    WHERE sli.guid = '${dependency.sli.outputs.sli_guid}'
  EOF

  alert_conditions_aggregation_window = local.window_seconds
  alert_conditions_slide_by           = 60

  alert_conditions_warning = {
    operator              = "above"
    threshold             = (100 - dependency.sli.outputs.service_level_target) * local.burn_rate
    threshold_duration    = local.window_seconds
    threshold_occurrences = "at_least_once"
  }
}
