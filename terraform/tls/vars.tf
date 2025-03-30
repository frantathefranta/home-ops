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

variable "node" {
  type    = string
  default = "10.32.10.50:8006"
}
