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
  alert_conditions_name               = "Microservice Too Many Error Logs"
  alert_conditions_aggregation_window = 60
  alert_conditions_enable             = true
  alert_conditions_aggregation_method = "event_timer"
  alert_conditions_aggregation_timer  = 60
  alert_conditions_aggregation_delay  = null
  alert_conditions_desc               = <<-EOF
    *What to Do:*
    1. Buka Logs di New Relic (filter level = error)
    2. Korelasikan ke transaction / service name
  EOF
  alert_conditions_runbook_url = "#"
  alert_conditions_query       = <<-EOF
    SELECT COUNT(*) as 'total error' FROM Log WHERE level = 'error' FACET entity.name
  EOF

  alert_conditions_warning = {
    operator              = "above"
    threshold             = 10
    threshold_duration    = 300
    threshold_occurrences = "at_least_once"
  }
  alert_conditions_critical = {
    operator              = "above"
    threshold             = 30
    threshold_duration    = 300
    threshold_occurrences = "at_least_once"
  }
  alert_conditions_expiration_duration            = 300
  alert_conditions_close_violations_on_expiration = true
}
