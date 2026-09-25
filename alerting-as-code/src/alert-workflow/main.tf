variable "alert_workflow_name" {}
variable "alert_workflow_muting_rules_handling" { default = "NOTIFY_ALL_ISSUES" }
variable "alert_policy_channel_ids" {
    type =  list(number)
    default = []
}
variable "alert_channel_id" {}
variable "alert_workflow_predicate_conditions" {
    type = list(object({
    attribute = string
    operator  = string
    values    = list(string)
  }))
  default = []
}
resource "newrelic_workflow" "AlertWorkflow" {
  name = "${var.alert_workflow_name}"
  muting_rules_handling = var.alert_workflow_muting_rules_handling

  issues_filter {
    name = "Filter-name"
    type = "FILTER"

    predicate {
      attribute = "labels.policyIds"
      operator = "EXACTLY_MATCHES"
      values = var.alert_policy_channel_ids
    }

   dynamic "predicate" {
      for_each = var.alert_workflow_predicate_conditions
      content {
        attribute = predicate.value.attribute
        operator  = predicate.value.operator
        values    = predicate.value.values
      }
    }
  }

  destination {
    channel_id = var.alert_channel_id
  }
}