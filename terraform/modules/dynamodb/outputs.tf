output "table_name" {
  description = "DynamoDB table name"
  value       = aws_dynamodb_table.urls.name
}

output "table_arn" {
  description = "DynamoDB table ARN"
  value       = aws_dynamodb_table.urls.arn
}

output "stream_arn" {
  description = "DynamoDB stream ARN"
  value       = aws_dynamodb_table.urls.stream_arn
}