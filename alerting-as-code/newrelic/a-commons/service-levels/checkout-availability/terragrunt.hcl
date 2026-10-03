include {
  path = find_in_parent_folders()
}

terraform {
  source = "../../../../src/service-level/"
}

dependency "checkout-journey" {
  config_path = "../../workloads/checkout-journey"
}

inputs = {
  service_level_guid = dependency.checkout-journey.outputs.workload_guid
  service_level_name = "Checkout — Availability"
  service_level_desc = "Proporsi request checkout yang tidak gagal karena sistem (bukan HTTP 5xx). Diukur di titik masuk checkout-svc."

  # Valid = semua request web ke titik masuk journey.
  service_level_valid_where = "appName = 'checkout-svc' AND transactionType = 'Web'"
  # Good = bukan error server. 4xx (input user salah) tidak menghabiskan budget.
  service_level_good_where  = "appName = 'checkout-svc' AND transactionType = 'Web' AND http.statusCode < 500"

  service_level_target      = 99.5
  service_level_window_days = 28
}
