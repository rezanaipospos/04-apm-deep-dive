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
  service_level_name = "Checkout — Latency < 3s"
  service_level_desc = "Proporsi request checkout yang selesai di bawah 3 detik. Diukur di titik masuk checkout-svc."

  service_level_valid_where = "appName = 'checkout-svc' AND transactionType = 'Web'"
  service_level_good_where  = "appName = 'checkout-svc' AND transactionType = 'Web' AND duration < 3"

  service_level_target      = 99
  service_level_window_days = 28
}
