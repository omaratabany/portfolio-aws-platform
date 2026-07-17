output "rule_arn" {
  description = "ARN of the check-schedule EventBridge rule"
  value       = aws_cloudwatch_event_rule.check_schedule.arn
}
