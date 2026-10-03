include {
  path = find_in_parent_folders()
}

terraform {
  source = "../../../../src/workload/"
}

inputs = {
  workload_name         = "Ticketing Lab — Checkout Journey"
  workload_desc         = "User journey bayar tiket: checkout-svc (titik masuk) → payment-svc → bank-svc (partner)."
  workload_entity_query = "domain = 'APM' AND type = 'APPLICATION' AND name IN ('checkout-svc', 'payment-svc', 'bank-svc')"
}
