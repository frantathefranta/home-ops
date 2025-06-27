locals {
  buckets = [
    "postgresql",
    "volsync",
    "dragonfly",
    "netbox"
  ]
}

module "buckets" {
  for_each    = toset(local.buckets)
  source      = "./modules/rgw"
  bucket_name = each.key
  providers = {
    rgw = rgw
  }
}
