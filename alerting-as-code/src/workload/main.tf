variable "workload_name" {}
variable "workload_desc" { default = "" }
variable "workload_entity_query" {}

resource "newrelic_workload" "Workload" {
  name              = var.workload_name
  account_id        = var.newrelic_account_id
  description       = var.workload_desc
  scope_account_ids = [var.newrelic_account_id]

  entity_search_query {
    query = var.workload_entity_query
  }
}

output "workload_guid" {
  value = newrelic_workload.Workload.guid
}

output "workload_permalink" {
  value = newrelic_workload.Workload.permalink
}
