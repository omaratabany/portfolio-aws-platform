output "user_name" {
  description = "IAM user name for the Grafana CloudWatch reader — used to generate an access key out-of-band (never via Terraform)"
  value       = aws_iam_user.grafana_reader.name
}

output "user_arn" {
  description = "ARN of the Grafana CloudWatch reader IAM user"
  value       = aws_iam_user.grafana_reader.arn
}
