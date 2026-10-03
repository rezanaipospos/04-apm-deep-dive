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
  alert_policy_id                     = dependency.service-anomaly.outputs.alert_policy_id
  alert_conditions_name               = "Microservice Slow External Call"
  alert_conditions_aggregation_window = 60
  alert_conditions_enable             = true
  alert_conditions_aggregation_method = "event_timer"
  alert_conditions_aggregation_timer  = 60
  alert_conditions_aggregation_delay  = null
  alert_conditions_desc               = <<-EOF
    *What to Do:*
    1. Buka APM service terkait → External services, urutkan by response time
    2. Pihak ketiga (payment gateway/bank) → hubungi partner + kirim trace ID
    3. Service internal → cek ke tim pemilik (traffic naik? deployment baru?)
    4. Untuk lab: ./chaos/enable.sh partner-latency
  EOF
  alert_conditions_runbook_url = "#"
  # externalDuration (detik) = waktu menunggu panggilan HTTP ke service lain dalam satu transaction.
  alert_conditions_query = <<-EOF
    SELECT percentile(externalDuration, 99) as 'External duration p99 (s)' FROM Transaction
    WHERE transactionType = 'Web' FACET appName
  EOF

  alert_conditions_warning = {
    operator              = "above"
    threshold             = 3
    threshold_duration    = 120
    threshold_occurrences = "at_least_once"
  }
  alert_conditions_critical = {
    operator              = "above"
    threshold             = 10
    threshold_duration    = 120
    threshold_occurrences = "at_least_once"
  }
  alert_conditions_expiration_duration            = 600
  alert_conditions_close_violations_on_expiration = true
}
