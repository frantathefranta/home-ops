module "secrets" {
  for_each          = toset(local.buckets)
  source            = "./modules/create-secret"
  name              = "${each.key}-bucket-rgw"
  username          = module.buckets[each.key].access_key
  password          = module.buckets[each.key].secret_key
}
