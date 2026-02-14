output "primary_api_endpoint" {
  description = "Primary region API endpoint"
  value       = module.api_gateway_primary.api_endpoint
}

output "secondary_api_endpoint" {
  description = "Secondary region API endpoint"
  value       = module.api_gateway_secondary.api_endpoint
}

output "primary_health_check" {
  description = "Primary health check endpoint"
  value       = "${module.api_gateway_primary.api_endpoint}/health"
}

output "secondary_health_check" {
  description = "Secondary health check endpoint"
  value       = "${module.api_gateway_secondary.api_endpoint}/health"
}

output "dynamodb_table_name" {
  description = "Global DynamoDB table name"
  value       = module.dynamodb_primary.table_name
}

output "route53_nameservers" {
  description = "Route 53 nameservers (if domain configured)"
  value       = var.domain_name != "" ? aws_route53_zone.main[0].name_servers : []
}

output "test_create_url_primary" {
  description = "Test command for primary region"
  value       = "curl -X POST ${module.api_gateway_primary.api_endpoint}/create -H 'Content-Type: application/json' -d '{\"longUrl\":\"https://github.com\"}'"
}

output "test_create_url_secondary" {
  description = "Test command for secondary region"
  value       = "curl -X POST ${module.api_gateway_secondary.api_endpoint}/create -H 'Content-Type: application/json' -d '{\"longUrl\":\"https://github.com\"}'"
}

output "failover_test_instructions" {
  description = "Instructions to test failover"
  value       = <<-EOT
    To test failover:
    1. Monitor primary health: watch -n 5 'curl ${module.api_gateway_primary.api_endpoint}/health'
    2. In another terminal, monitor secondary: watch -n 5 'curl ${module.api_gateway_secondary.api_endpoint}/health'
    3. To simulate failure, disable primary health check in Route 53 console
    4. Watch Route 53 automatically failover to secondary region
    5. Verify data replication by creating URL in one region and reading from another
  EOT
}