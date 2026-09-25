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
  alert_conditions_name               = "Microservice Down (Zero Throughput)"
  alert_conditions_aggregation_window = 60
  alert_conditions_enable             = true
  alert_conditions_desc               = <<-EOF
    *What to Do:*
    1. Cek docker compose ps — apakah service masih Up?
    2. Cek log service terkait
  EOF
  alert_conditions_runbook_url = "#"
  alert_conditions_query       = <<-EOF
    SELECT rate(count(apm.service.transaction.duration), 1 minute) as 'Web throughput'
    FROM Metric WHERE transactionType = 'Web' FACET entity.name
  EOF

  alert_conditions_critical = {
    operator              = "equals"
    threshold             = 0
    threshold_duration    = 900
    threshold_occurrences = "all"
  }
  alert_conditions_expiration_duration            = 300
  alert_conditions_close_violations_on_expiration = true
}
