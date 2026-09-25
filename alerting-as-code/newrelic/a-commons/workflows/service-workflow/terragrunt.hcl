include {
  path = find_in_parent_folders()
}

terraform {
  source = "../../../../src/alert-workflow/"
}

dependency "slack-911-incident" {
  config_path = "../../channels/slack/911-incident"
}

dependency "service-anomaly" {
  config_path = "../../policies/service-anomaly"
}

inputs = {
  alert_workflow_name      = "Ticketing Lab — Service Anomaly Workflow"
  alert_channel_id         = dependency.slack-911-incident.outputs.alert_channel_id
  alert_policy_channel_ids = [dependency.service-anomaly.outputs.alert_policy_id]
}
