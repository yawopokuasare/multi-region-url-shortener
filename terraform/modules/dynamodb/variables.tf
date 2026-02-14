variable "table_name" {
  description = "Name of the DynamoDB table"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "enable_streams" {
  description = "Enable DynamoDB streams for global tables"
  type        = bool
  default     = false
}

variable "replica_region" {
  description = "Region for global table replica (empty string = no replica)"
  type        = string
  default     = ""
}

variable "tags" {
  description = "Additional tags"
  type        = map(string)
  default     = {}
}