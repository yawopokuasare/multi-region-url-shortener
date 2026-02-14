output "api_endpoint" {
  description = "API Gateway endpoint"
  value       = module.api_gateway.api_endpoint
}

output "dynamodb_table_name" {
  description = "DynamoDB table name"
  value       = module.dynamodb.table_name
}

output "test_create_url" {
  description = "Test command to create a short URL"
  value       = "curl -X POST ${module.api_gateway.api_endpoint}/create -H 'Content-Type: application/json' -d '{\"longUrl\":\"https://github.com\"}'"
}

output "test_health" {
  description = "Test command to check health"
  value       = "curl ${module.api_gateway.api_endpoint}/health"
}