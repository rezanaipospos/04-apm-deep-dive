variable "json_file_path" {
  description = "Path to the JSON file"
  default     = "outlet.json"
}

# old
# variable "tags" {
#   description = "tags of entity"
# }
# variable "tagKeyName" {
#   description = "key of Json value"
# }

# new
variable "tags" {
  description = "tags of entity"
  type        = list(object({
    key     = string
    value   = string
  }))
}

data "local_file" "outlet_data" {
  filename = var.json_file_path
}

# restructure schema data, validate value and split of key HostName (string to array) 
locals {
  original_data = jsondecode(data.local_file.outlet_data.content)
  modified_data = [
    for item in local.original_data : {
        No                  = item["No"]
        "NamaBioskop"       = item["Nama Bioskop"]
        "outletSupport"       = item["outletSupport"]
        # "KodeMtix"          = coalesce(lookup(item, "Kode Mtix"), "")
        # "IPAddressIntranet" = coalesce(lookup(item, "IP Address Intranet"), "")
        # Port                = coalesce(lookup(item, "Port"), "")
        HostName            = trim(item["HostName"]," ") != "" ? split(";", item["HostName"]) : []
    }
  ]
}

# restructure schema data,
locals {
  json_data = flatten([
    for item in local.modified_data : [
      for host in item.HostName : {
        "No"            = item.No
        "NamaBioskop"   = item["NamaBioskop"]
        "HostName"      = trim(host," ")
        "outletSupport"   = item["outletSupport"]
      }
    ]
  ])
    host_names = {
    for idx, item in local.json_data : idx => item.HostName
    }
}

resource "local_file" "json_file" {
 content = jsonencode(local.host_names)
 filename = "${path.root}/host_names.json"
}

output "data" {
  value = {
    for idx, data in local.json_data : idx => {
      index = idx
      content = data
    }
  }
}

data "newrelic_entity" "host_tags" {
  # for_each = {
  #   for index, item in local.json_data :
  #   index => item
  # }
  for_each = local.host_names
  name   = each.value
  type   = "HOST"
  domain = "INFRA"
  ignore_not_found = true
}


output "newrelic_entity_179" {
  value = [for tag in data.newrelic_entity.host_tags : tag if tag.guid == null]
}
# locals {
#   filtered_host_tags = [for tag in data.newrelic_entity.host_tags : tag if tag.guid != null]
# }

locals {
  # Map each hostname to its corresponding entity guid
  guid_map = {
    for hostname, entity in data.newrelic_entity.host_tags : 
      hostname => entity.guid
  }

  # Map each entity guid to its corresponding item in json_data
  json_data_with_guid = {
    for hostname, guid in local.guid_map : 
      guid => {
        No            = lookup(local.json_data[hostname], "No", null)
        NamaBioskop   = lookup(local.json_data[hostname], "NamaBioskop", null)
        HostName      = lookup(local.json_data[hostname], "HostName", null)
        outletSupport      = lookup(local.json_data[hostname], "outletSupport", null)
      }
  }
}

output "name" {
   value = local.json_data_with_guid
}
resource "newrelic_entity_tags" "result" {
  for_each = local.json_data_with_guid

  guid = each.key
  dynamic "tag" {
    for_each = var.tags

    content {
      key    = tag.value["key"]
      values = [each.value[tag.value["value"]]]
    }
  }
}