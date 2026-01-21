terraform {
  required_providers {
    proxmox = {
      source = "bpg/proxmox"
      version = "0.93.0"
    }
    akeyless = {
      source  = "akeyless-community/akeyless"
      version = "1.11.4"
    }
  }
}

provider "akeyless" {
  api_key_login {
    access_id = var.access_id
    access_key = var.access_key
  }
}

data "akeyless_static_secret" "proxmox_secret" {
  path = "/proxmox"
}

locals {
  proxmox_secret_data = jsondecode(data.akeyless_static_secret.proxmox_secret.value)
  decoded_ssh_key = base64decode(local.proxmox_secret_data["TF_SSH_KEY"])
}

provider "proxmox" {
  endpoint  = "https://${var.node}"
  api_token = local.proxmox_secret_data.TF_TOKEN
  insecure  = true
  tmp_dir   = "/var/tmp"

  ssh {
    agent       = false
    username    = "root"
    private_key = local.decoded_ssh_key
  }
}
