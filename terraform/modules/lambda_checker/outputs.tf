output "function_name" {
  description = "Name of the checker Lambda function"
  value       = aws_lambda_function.checker.function_name
}

output "function_arn" {
  description = "ARN of the checker Lambda function"
  value       = aws_lambda_function.checker.arn
}
