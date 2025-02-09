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
  default     = "http://haproxy-rados-gw.rook-ceph-external.svc.cluster.local:7480"
}
