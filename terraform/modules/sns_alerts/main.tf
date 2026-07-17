resource "aws_sns_topic" "status_alerts" {
  name = "${var.project}-${var.environment}-status-alerts"
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.status_alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email

  # AWS emails a confirmation link to alert_email after apply — the
  # subscription stays PendingConfirmation and won't deliver anything
  # until that link is clicked. Terraform can't do this step for you.
}
