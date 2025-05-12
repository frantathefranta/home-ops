terraform {
  backend "s3" {
    bucket = "terraform-state"
    key    = "rgw/rgw-buckets.tfstate"
    region = "main" # Region validation will be skipped

    endpoints = {
      s3 = "http://10.40.1.50:7480" # RGW endpoint
    }

    skip_credentials_validation = true
    skip_requesting_account_id  = true
    skip_metadata_api_check     = true
    skip_region_validation      = true
    use_path_style              = true
  }
}
