output "checker_exec_role_arn" {
  description = "ARN of the checker Lambda's execution role"
  value       = aws_iam_role.checker_exec.arn
}

output "api_exec_role_arn" {
  description = "ARN of the api Lambda's execution role"
  value       = aws_iam_role.api_exec.arn
}
