output "parameter_name" {
  description = "Name of the SSM parameter holding the target list"
  value       = aws_ssm_parameter.monitor_targets.name
}

output "parameter_arn" {
  description = "ARN of the SSM parameter holding the target list"
  value       = aws_ssm_parameter.monitor_targets.arn
}
