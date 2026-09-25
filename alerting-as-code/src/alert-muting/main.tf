variable "alert_muting_name" {}
variable "alert_muting_enable" { default = false }
variable "alert_muting_desc" {}
variable "alert_muting_start_time" {}
variable "alert_muting_end_time" {}
variable "alert_muting_time_zone" {}
variable "alert_muting_repeat" {}
variable "alert_muting_weekly_repeat_days" {}
variable "alert_muting_repeat_count" {}
variable "alert_muting_operator" { default = "AND" }
variable "alert_muting_conditions" {
  description = "List of conditions for the alert muting rule"
  type        = list(object({
    attribute = string
    operator  = string
    values    = list(string)
  }))
}

resource "newrelic_alert_muting_rule" "AlertMuting" {
    account_id = 3944992
    name = var.alert_muting_name
    enabled = var.alert_muting_enable
    description = var.alert_muting_desc
    condition {
      dynamic "conditions" {
        for_each = var.alert_muting_conditions
        content {
          attribute = conditions.value.attribute
          operator  = conditions.value.operator
          values    = conditions.value.values
        }
      }

      operator = var.alert_muting_operator
    }
    schedule {
      start_time = var.alert_muting_start_time
      end_time = var.alert_muting_end_time
      time_zone = var.alert_muting_time_zone
      repeat = var.alert_muting_repeat
      weekly_repeat_days = var.alert_muting_weekly_repeat_days
      repeat_count = var.alert_muting_repeat_count
    }
}