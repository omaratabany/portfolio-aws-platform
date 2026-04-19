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