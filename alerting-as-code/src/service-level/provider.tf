terraform {
  required_version = "~> 1.0"
  required_providers {
    newrelic = {
      source  = "newrelic/newrelic"
      version = "~> 3.28.1"
    }
  }
}

variable "newrelic_personal_apikey" {}
variable "newrelic_account_id" {}
variable "newrelic_region" {
  type    = string
  default = "US"
}

provider "newrelic" {
  account_id = var.newrelic_account_id
  api_key    = var.newrelic_personal_apikey
  region     = var.newrelic_region
}
