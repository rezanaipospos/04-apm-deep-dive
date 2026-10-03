variable "service_level_guid" {}
variable "service_level_name" {}
variable "service_level_desc" { default = "" }
variable "service_level_event_type" { default = "Transaction" }
variable "service_level_valid_where" {}
variable "service_level_good_where" {}
variable "service_level_target" {}
# New Relic only accepts 1, 7, or 28.
variable "service_level_window_days" { default = 28 }

resource "newrelic_service_level" "ServiceLevel" {
  guid        = var.service_level_guid
  name        = var.service_level_name
  description = var.service_level_desc

  events {
    account_id = var.newrelic_account_id
    valid_events {
      from  = var.service_level_event_type
      where = var.service_level_valid_where
    }
    good_events {
      from  = var.service_level_event_type
      where = var.service_level_good_where
    }
  }

  objective {
    target = var.service_level_target
    time_window {
      rolling {
        count = var.service_level_window_days
        unit  = "DAY"
      }
    }
  }
}

output "sli_guid" {
  value = newrelic_service_level.ServiceLevel.sli_guid
}

output "service_level_target" {
  value = var.service_level_target
}

output "service_level_window_days" {
  value = var.service_level_window_days
}
