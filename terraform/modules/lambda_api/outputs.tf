output "function_name" {
  description = "Name of the status-api Lambda function"
  value       = aws_lambda_function.status_api.function_name
}

output "invoke_arn" {
  description = "Invoke ARN for API Gateway integration"
  value       = aws_lambda_function.status_api.invoke_arn
}
