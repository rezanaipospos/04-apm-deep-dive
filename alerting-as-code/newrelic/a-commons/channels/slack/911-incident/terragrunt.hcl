include {
  path = find_in_parent_folders()
}

terraform {
  source = "../../../../../src/alert-channel/"
}

inputs = {
  alert_channel_name           = "ticketing-lab-incident"
  alert_channel_slack_id       = get_env("NEW_RELIC_SLACK_CHANNEL_ID", "your-slack-channel-id-here")
  alert_channel_destination_id = get_env("NEW_RELIC_SLACK_DESTINATION_ID", "")
}
