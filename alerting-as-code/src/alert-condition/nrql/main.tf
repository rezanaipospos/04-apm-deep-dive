variable "alert_policy_id" {}
variable "alert_conditions_type" {default = "static"}
variable "alert_conditions_name" {}
variable "alert_conditions_desc" {}
variable "alert_conditions_runbook_url" {}
variable "alert_conditions_query" {}
variable "alert_conditions_enable" {default = true}
variable "alert_conditions_violation_time_limit_seconds" { default = 28800 }
variable "alert_conditions_fill_option" { default = "none" }
variable "alert_conditions_fill_value" { default = 0 }
variable "alert_conditions_aggregation_window" {}
variable "alert_conditions_aggregation_method" {default = "event_flow"}
variable "alert_conditions_aggregation_delay" {default = 120}
variable "alert_conditions_aggregation_timer" {default = null}
variable "alert_conditions_expiration_duration" {default = null}
variable "alert_conditions_open_violation_on_expiration" {default = false}
variable "alert_conditions_close_violations_on_expiration" {default = false}
variable "alert_conditions_slide_by" {default = null}
variable "alert_conditions_critical" {
  type = object({
    operator              = string
    threshold             = number
    threshold_duration    = number
    threshold_occurrences = string
  })
  default = null
}

variable "alert_conditions_warning" {
  type = object({
    operator              = string
    threshold             = number
    threshold_duration    = number
    threshold_occurrences = string
  })
  default = null
}

resource "newrelic_nrql_alert_condition" "AlertCondition" {
  type                         = var.alert_conditions_type
  account_id                   = var.newrelic_account_id
  name                         = var.alert_conditions_name
  policy_id                    = var.alert_policy_id
  description                  = var.alert_conditions_desc
  enabled                        = var.alert_conditions_enable
  violation_time_limit_seconds   = var.alert_conditions_violation_time_limit_seconds
  fill_option                    = var.alert_conditions_fill_option
  fill_value                     = var.alert_conditions_fill_value
  aggregation_window             = var.alert_conditions_aggregation_window
  aggregation_method             = var.alert_conditions_aggregation_method
  aggregation_delay              = var.alert_conditions_aggregation_delay
  aggregation_timer              = var.alert_conditions_aggregation_timer
  expiration_duration            = var.alert_conditions_expiration_duration
  open_violation_on_expiration   = var.alert_conditions_open_violation_on_expiration
  close_violations_on_expiration = var.alert_conditions_close_violations_on_expiration
  slide_by                       = var.alert_conditions_slide_by

  nrql {
    query = var.alert_conditions_query
  }

  // Check if critical conditions should be included
  dynamic "critical" {
    for_each = var.alert_conditions_critical != null ? [1] : []
    content {
      operator              = var.alert_conditions_critical.operator
      threshold             = var.alert_conditions_critical.threshold
      threshold_duration    = var.alert_conditions_critical.threshold_duration
      threshold_occurrences = var.alert_conditions_critical.threshold_occurrences
    }
  }

  // Check if warning conditions should be included
  dynamic "warning" {
    for_each = var.alert_conditions_warning != null ? [1] : []
    content {
      operator              = var.alert_conditions_warning.operator
      threshold             = var.alert_conditions_warning.threshold
      threshold_duration    = var.alert_conditions_warning.threshold_duration
      threshold_occurrences = var.alert_conditions_warning.threshold_occurrences
    }
  }
}