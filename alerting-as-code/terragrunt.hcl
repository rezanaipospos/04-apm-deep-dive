locals {
  env_name = path_relative_to_include()
}

# New Relic credentials from environment.
#   export NEW_RELIC_ACCOUNT_ID=1234567
#   export NEW_RELIC_USER_API_KEY=NRAK-xxxxxxxx   # User key (bukan ingest license)
#   export NEW_RELIC_REGION=US                    # atau EU
inputs = {
  env_name                   = local.env_name
  newrelic_account_id        = tonumber(get_env("NEW_RELIC_ACCOUNT_ID", "0"))
  newrelic_personal_apikey   = get_env("NEW_RELIC_USER_API_KEY", "")
  newrelic_region            = get_env("NEW_RELIC_REGION", "US")
  # Optional Slack destination (New Relic → Destination). Leave empty to skip channel/workflow apply.
  alert_channel_destination_id = get_env("NEW_RELIC_SLACK_DESTINATION_ID", "")
}

remote_state {
  backend = "local"
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }
  config = {
    path = "${get_parent_terragrunt_dir()}/.terragrunt-local-state/${path_relative_to_include()}/terraform.tfstate"
  }
}
