variable "primary_region" {
  description = "Primary AWS region"
  type        = string
  default     = "us-east-1"
}

variable "secondary_region" {
  description = "Secondary AWS region for failover"
  type        = string
  default     = "us-west-2"
}

variable "domain_name" {
  description = "Domain name for Route 53 (leave empty to skip Route 53 setup)"
  type        = string
  default     = ""
}