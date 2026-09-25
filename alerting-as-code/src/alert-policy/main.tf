variable "env_name" {}
variable "alert_policy_name" {}
variable "alert_policy_preference" { default = "PER_CONDITION" }

resource "newrelic_alert_policy" "AlertPolicy" {
    name = "${var.alert_policy_name}"
    incident_preference = var.alert_policy_preference
}

output "alert_policy_id" {
  value = tonumber(newrelic_alert_policy.AlertPolicy.id)
}