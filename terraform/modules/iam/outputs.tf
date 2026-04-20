output "lambda_exec_role_arn" {
  description = "ARN of the Lambda ececution role"
  value       = aws_iam_role.lambda_exec.arn
}

output "lambda_exec_role_name" {
  description = "name of the lambda execution role"
  value       = aws_iam_role.lambda_exec.name
}

output "github_actions_role_arn" {
  description = "ARN of the IAM role assumed by GitHub Actions via OIDC"
  value       = aws_iam_role.github_actions.arn
}