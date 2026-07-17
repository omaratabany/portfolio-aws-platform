resource "aws_cloudwatch_event_rule" "check_schedule" {
  name                = "${var.project}-${var.environment}-status-check-schedule"
  description         = "Triggers the status checker Lambda on a fixed interval"
  schedule_expression = "rate(5 minutes)"
}

resource "aws_cloudwatch_event_target" "checker" {
  rule = aws_cloudwatch_event_rule.check_schedule.name
  arn  = var.checker_function_arn
}

resource "aws_lambda_permission" "eventbridge" {
  statement_id  = "AllowEventBridgeInvoke"
  action        = "lambda:InvokeFunction"
  function_name = var.checker_function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.check_schedule.arn
}
