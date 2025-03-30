data "akeyless_static_secret" "infra-franta-us_secret" {
  path = "/infra-franta-us-tls"
}

locals {
  nodes = [
    "actinium.infra.franta.us",
    "thorium.infra.franta.us",
    "protactinium.infra.franta.us"
  ]
  infra-franta-us_secret_data = jsondecode(data.akeyless_static_secret.infra-franta-us_secret.value)
  base64decoded_cert          = base64decode(lookup(local.infra-franta-us_secret_data, "tls.crt"))
  leaf_certificate            = regexall("-----BEGIN CERTIFICATE-----[\\s\\S]*?-----END CERTIFICATE-----", local.base64decoded_cert)
}
resource "proxmox_virtual_environment_certificate" "thorium" {
  node_name         = "thorium"
  certificate       = "${local.leaf_certificate[0]}\n"
  certificate_chain = length(local.leaf_certificate) > 1 ? local.leaf_certificate[1] : ""
  private_key       = base64decode(lookup(local.infra-franta-us_secret_data, "tls.key"))
  lifecycle {
    ignore_changes = [
      certificate_chain
    ]
  }
}
resource "proxmox_virtual_environment_certificate" "protactinium" {
  node_name         = "protactinium"
  certificate       = "${local.leaf_certificate[0]}\n"
  certificate_chain = length(local.leaf_certificate) > 1 ? local.leaf_certificate[1] : ""
  private_key       = base64decode(lookup(local.infra-franta-us_secret_data, "tls.key"))
  lifecycle {
    ignore_changes = [
      certificate_chain
    ]
  }
}

resource "proxmox_virtual_environment_certificate" "actinium" {
  depends_on = [
    proxmox_virtual_environment_certificate.protactinium,
    proxmox_virtual_environment_certificate.thorium
  ]
  node_name         = "actinium"
  certificate       = "${local.leaf_certificate[0]}\n"
  certificate_chain = length(local.leaf_certificate) > 1 ? local.leaf_certificate[1] : ""
  private_key       = base64decode(lookup(local.infra-franta-us_secret_data, "tls.key"))
  lifecycle {
    ignore_changes = [
      certificate_chain
    ]
  }
}
