output "topic_arn" {
  description = "ARN of the status-alerts SNS topic"
  value       = aws_sns_topic.status_alerts.arn
}
