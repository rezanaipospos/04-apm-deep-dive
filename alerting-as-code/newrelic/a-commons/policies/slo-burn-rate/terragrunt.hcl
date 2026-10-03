include {
  path = find_in_parent_folders()
}

terraform {
  source = "../../../../src/alert-policy/"
}

inputs = {
  alert_policy_name       = "Ticketing Lab — SLO Burn Rate"
  alert_policy_preference = "PER_CONDITION"
}
