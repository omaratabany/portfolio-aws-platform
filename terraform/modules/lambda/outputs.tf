output "function_name" {
  description = "Name of the Lambda function"
  value       = aws_lambda_function.ingest.function_name
}

output "function_arn" {
  description = "ARN of the Lambda function"
  value       = aws_lambda_function.ingest.arn
}

output "invoke_arn" {
  description = "Invoke ARN used by API Gateway to trigger the Lambda function"
  value       = aws_lambda_function.ingest.invoke_arn
}