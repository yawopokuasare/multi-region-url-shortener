variable "api_name" {
  description = "API Gateway name"
  type        = string
}

variable "create_lambda_name" {
  description = "Create URL Lambda function name"
  type        = string
}

variable "create_lambda_invoke_arn" {
  description = "Create URL Lambda invoke ARN"
  type        = string
}

variable "redirect_lambda_name" {
  description = "Redirect Lambda function name"
  type        = string
}

variable "redirect_lambda_invoke_arn" {
  description = "Redirect Lambda invoke ARN"
  type        = string
}

variable "health_lambda_name" {
  description = "Health check Lambda function name"
  type        = string
}

variable "health_lambda_invoke_arn" {
  description = "Health check Lambda invoke ARN"
  type        = string
}

variable "tags" {
  description = "Tags to apply"
  type        = map(string)
  default     = {}
}