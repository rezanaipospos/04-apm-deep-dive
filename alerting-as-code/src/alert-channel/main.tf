variable "env_name" {}
variable "alert_channel_name" {}
variable "alert_channel_slack_id" {}
variable "alert_channel_destination_id" {
  type        = string
  description = "New Relic notification destination ID for Slack (from NR UI → Destinations)."
}
variable "newrelic_account_id" {}

resource "newrelic_notification_channel" "AlertChannel" {
  account_id     = var.newrelic_account_id
  name           = var.alert_channel_name
  type           = "SLACK"
  destination_id = var.alert_channel_destination_id
  product        = "IINT"

  property {
    key   = "channelId"
    value = var.alert_channel_slack_id
  }
}

output "alert_channel_id" {
  value = newrelic_notification_channel.AlertChannel.id
}
