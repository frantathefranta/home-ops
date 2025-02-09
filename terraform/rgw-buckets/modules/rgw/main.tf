terraform {
  required_providers {
    rgw = {
      source  = "registry.terraform.io/sergeyyegournov/rgw"
      version = "1.0.16"
    }
  }
}

resource "rgw_bucket" "bucket" {
  name = var.bucket_name
}

resource "rgw_user" "user" {
  username   = var.bucket_name
  display_name = var.bucket_name
  generate_s3_credentials = true
  exclusive_s3_credentials = true
}

resource "rgw_bucket_policy" "policy" {
  bucket = rgw_bucket.bucket.name
    policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "s3:ListBucket",
        "s3:DeleteObject",
        "s3:GetObject",
        "s3:PutObject",
        "s3:AbortMultipartUpload",
        "s3:ListAllMyBuckets"
      ]
      Resource = [
        "arn:aws:s3:::${rgw_bucket.bucket.name}/*",
        "arn:aws:s3:::${rgw_bucket.bucket.name}",
      ]
    }]
  })
}
