variable "access_id" {
  type        = string
  description = "Akeyless Access ID"
  sensitive   = true
  default     = null
}

variable "access_key" {
  type        = string
  description = "Akeyless Access Key"
  sensitive   = true
  default     = null
}

variable "rgw_endpoint" {
  type        = string
  description = "Rados GW Server URL"
  default     = "https://rgw.franta.us"
}
