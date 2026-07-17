output "table_name" {
  description = "Name of the UptimeChecks DynamoDB table"
  value       = aws_dynamodb_table.uptime_checks.name
}

output "table_arn" {
  description = "ARN of the UptimeChecks DynamoDB table"
  value       = aws_dynamodb_table.uptime_checks.arn
}
