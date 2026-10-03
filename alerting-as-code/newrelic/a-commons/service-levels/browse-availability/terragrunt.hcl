include {
  path = find_in_parent_folders()
}

terraform {
  source = "../../../../src/service-level/"
}

dependency "browse-journey" {
  config_path = "../../workloads/browse-journey"
}

inputs = {
  service_level_guid = dependency.browse-journey.outputs.workload_guid
  service_level_name = "Browse Film & Kursi — Availability"
  service_level_desc = "Proporsi request daftar film + denah kursi yang tidak gagal karena sistem (bukan HTTP 5xx)."

  service_level_valid_where = "appName IN ('cinema-svc', 'layout-svc') AND transactionType = 'Web'"
  service_level_good_where  = "appName IN ('cinema-svc', 'layout-svc') AND transactionType = 'Web' AND http.statusCode < 500"

  service_level_target      = 99.9
  service_level_window_days = 28
}
