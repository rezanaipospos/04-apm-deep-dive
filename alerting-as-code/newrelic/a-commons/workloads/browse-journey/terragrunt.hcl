include {
  path = find_in_parent_folders()
}

terraform {
  source = "../../../../src/workload/"
}

inputs = {
  workload_name         = "Ticketing Lab — Browse Film & Kursi Journey"
  workload_desc         = "User journey lihat film & pilih kursi: cinema-svc (daftar film) + layout-svc (denah kursi)."
  workload_entity_query = "domain = 'APM' AND type = 'APPLICATION' AND name IN ('cinema-svc', 'layout-svc')"
}
