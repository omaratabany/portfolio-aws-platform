output "api_endpoint" {
  description = "Base URL of the API Gateway HTTP endpoint"
  value       = module.apigateway.api_endpoint
}

output "bucket_id" {
  description = "Name of the S3 data bucket"
  value       = module.storage.bucket_id
}

output "lambda_function_name" {
  description = "Name of the Lambda ingest function"
  value       = module.lambda.function_name
}

output "github_actions_role_arn" {
  description = "ARN of the IAM role assumed by GitHub Actions via OIDC"
  value       = module.iam.github_actions_role_arn
}

output "status_api_endpoint" {
  description = "Base URL of the status monitor's public API"
  value       = module.apigateway_monitor.api_endpoint
}

output "uptime_table_name" {
  description = "Name of the UptimeChecks DynamoDB table"
  value       = module.dynamodb.table_name
}

output "status_alerts_topic_arn" {
  description = "ARN of the SNS topic for status-change alerts"
  value       = module.sns_alerts.topic_arn
}