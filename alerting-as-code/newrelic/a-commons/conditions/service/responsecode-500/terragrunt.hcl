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
  alert_conditions_name               = "Microservice Too Many Response Code 500"
  alert_conditions_aggregation_window = 60
  alert_conditions_enable             = true
  alert_conditions_desc               = <<-EOF
    *What to Do:*
    1. Buka Errors / TransactionError di New Relic
    2. Untuk lab: ./chaos/enable.sh payment-500
  EOF
  alert_conditions_runbook_url = "#"
  alert_conditions_query       = <<-EOF
    FROM TransactionError SELECT count(*) WHERE error.class = '500' FACET appName
  EOF

  alert_conditions_critical = {
    operator              = "above_or_equals"
    threshold             = 5
    threshold_duration    = 60
    threshold_occurrences = "at_least_once"
  }
  alert_conditions_expiration_duration            = 300
  alert_conditions_open_violation_on_expiration   = false
}
