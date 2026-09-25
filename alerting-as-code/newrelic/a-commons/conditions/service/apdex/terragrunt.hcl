include {
  path = find_in_parent_folders()
}

terraform {
  source = "../../../../../src/alert-condition/nrql/"
}

dependency "service-anomaly" {
  config_path = "../../../policies/service-anomaly"
}

inputs = {
  alert_policy_id                   = dependency.service-anomaly.outputs.alert_policy_id
  alert_conditions_name             = "Microservice Low Apdex Score"
  alert_conditions_aggregation_window = 60
  alert_conditions_enable           = true
  alert_conditions_desc             = <<-EOF
    *What to Do:*
    1. Buka APM Summary service terkait di New Relic
    2. Cek latency / error rate / Apdex
    3. Untuk lab: jalankan chaos atau pastikan loadgen hidup
  EOF
  alert_conditions_runbook_url = "#"
  alert_conditions_query       = <<-EOF
    SELECT apdex(apm.service.apdex) as 'App server' FROM Metric FACET entity.name
  EOF

  alert_conditions_critical = {
    operator              = "below"
    threshold             = 0.7
    threshold_duration    = 300
    threshold_occurrences = "all"
  }
  alert_conditions_expiration_duration          = 1800
  alert_conditions_open_violation_on_expiration = true
}
