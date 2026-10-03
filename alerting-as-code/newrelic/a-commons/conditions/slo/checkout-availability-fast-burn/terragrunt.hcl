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
  # Fast burn (Google SRE): 2% budget habis dalam 1 jam.
  # burn rate = (0.02 * 28 hari * 24 jam) / 1 jam = 13.44
  burn_rate      = 13.44
  window_seconds = 3600
}

inputs = {
  alert_policy_id       = dependency.slo-burn-rate.outputs.alert_policy_id
  alert_conditions_name = "SLO Fast Burn — Checkout Availability"
  alert_conditions_enable = true
  alert_conditions_desc = <<-EOF
    *Arti:* error budget Checkout Availability terbakar >= 13.44x lebih cepat dari normal
    (2% budget 28 hari habis dalam 1 jam). Jika dibiarkan, budget habis < 3 hari.
    *What to Do:*
    1. Buka Service Levels → Checkout — Availability, lihat kapan SLI mulai turun
    2. Buka workload Checkout Journey → service mana yang error (checkout / payment / bank)?
    3. Ikuti runbook 3.2 (symptom → service → change → errors → deps)
    4. Lab: kemungkinan chaos payment-500 aktif → ./chaos/disable.sh
  EOF
  alert_conditions_runbook_url = "#"
  alert_conditions_query       = <<-EOF
    FROM Metric SELECT 100 - clamp_max(sum(newrelic.sli.good) / sum(newrelic.sli.valid) * 100, 100) AS 'Bad events (%)'
    WHERE sli.guid = '${dependency.sli.outputs.sli_guid}'
  EOF

  alert_conditions_aggregation_window = local.window_seconds
  alert_conditions_slide_by           = 60

  alert_conditions_critical = {
    operator              = "above"
    threshold             = (100 - dependency.sli.outputs.service_level_target) * local.burn_rate
    threshold_duration    = local.window_seconds
    threshold_occurrences = "at_least_once"
  }
}
