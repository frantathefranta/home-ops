terraform {
  required_providers {
    rgw = {
      source  = "registry.terraform.io/sergeyyegournov/rgw"
      version = "1.0.16"
    }
    akeyless = {
      source  = "akeyless-community/akeyless"
      version = "1.10.4"
    }
  }
}


provider "akeyless" {
  api_key_login {
    access_id = var.access_id
    access_key = var.access_key
  }
}

data "akeyless_static_secret" "rgw_secret" {
  path = "/rook-ceph"
}

locals {
  rgw_secret_data = jsondecode(data.akeyless_static_secret.rgw_secret.value)
}

provider "rgw" {
  endpoint = var.rgw_endpoint
  access_key = local.rgw_secret_data.RGW_ADMIN_OPS_USER_ACCESS_KEY
  secret_key = local.rgw_secret_data.RGW_ADMIN_OPS_USER_SECRET_KEY
}
