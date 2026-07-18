data "archive_file" "checker" {
  type        = "zip"
  source_file = "${path.root}/../functions/checker.py"
  output_path = "${path.root}/../functions/checker.zip"
}

resource "aws_lambda_function" "checker" {
  function_name    = "${var.project}-${var.environment}-status-checker"
  role             = var.exec_role_arn
  handler          = "checker.handler"
  runtime          = "python3.12"
  timeout          = 15
  filename         = data.archive_file.checker.output_path
  source_code_hash = data.archive_file.checker.output_base64sha256

  # See the reserved_concurrent_executions note in modules/lambda/main.tf
  # — reverted account-wide, not just here.

  tracing_config {
    mode = "Active"
  }

  environment {
    variables = {
      TABLE_NAME     = var.table_name
      SNS_TOPIC_ARN  = var.sns_topic_arn
      SSM_PARAM_NAME = var.ssm_parameter_name
    }
  }

  depends_on = [aws_cloudwatch_log_group.checker]
}

# Without this, Lambda auto-creates the log group on first invocation
# with NO expiration — logs would accumulate forever. Neither this nor
# Checkov's CKV_AWS_338 (>= 1 year) fully agree on "correct" here: for a
# $0-ceiling personal project, bounding cost matters more than
# audit-grade retention, so this deliberately stays short — see
# reports/03-cicd-hardening.md.
resource "aws_cloudwatch_log_group" "checker" {
  # Deliberately a literal string matching the Lambda's function_name
  # above, not a reference to it — depends_on needs this log group
  # created *before* the function, so the function can't be the source
  # of this name without a dependency cycle. Lambda writes logs to
  # /aws/lambda/<function name> automatically once it exists.
  name              = "/aws/lambda/${var.project}-${var.environment}-status-checker"
  retention_in_days = 14
}

# Alarms live here, not in the shared `observability` module (which
# ingest uses) — that module also creates its own log group, and this
# one already has one above. Splitting "alarms" from "log group +
# alarms" for one Lambda but not another would be more confusing than
# just letting each Lambda module own its own full observability story.
# Reuses the same SNS topic as status-change alerts (var.sns_topic_arn)
# rather than a second topic — one recipient, one $0 topic, not two.

resource "aws_cloudwatch_metric_alarm" "checker_errors" {
  alarm_name          = "${var.project}-${var.environment}-status-checker-errors"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 300
  statistic           = "Sum"
  threshold           = 1
  alarm_description   = "The status-checker Lambda itself failed to run (crash, timeout, throttle) — different from a monitored site being down."
  treat_missing_data  = "notBreaching"
  alarm_actions       = [var.sns_topic_arn]
  ok_actions          = [var.sns_topic_arn]

  dimensions = {
    FunctionName = aws_lambda_function.checker.function_name
  }
}

resource "aws_cloudwatch_metric_alarm" "checker_duration" {
  alarm_name          = "${var.project}-${var.environment}-status-checker-duration"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "Duration"
  namespace           = "AWS/Lambda"
  period              = 300
  # Maximum, not Average — an average over the 5-minute period would let
  # one genuinely slow/hanging invocation get diluted by several fast
  # ones and never cross the threshold. Maximum catches the single worst
  # invocation in the period, which is what this alarm is actually for.
  statistic          = "Maximum"
  threshold          = 10000 # ms — well under the 15s function timeout
  alarm_description  = "The status-checker Lambda is running unusually long — likely a slow/hanging target, not the checker itself."
  treat_missing_data = "notBreaching"
  alarm_actions      = [var.sns_topic_arn]

  dimensions = {
    FunctionName = aws_lambda_function.checker.function_name
  }
}

resource "aws_cloudwatch_metric_alarm" "checker_throttles" {
  # Errors alone won't catch this: a throttled invocation never runs user
  # code, so it doesn't count as a Lambda "Error" — it's a distinct metric.
  # Worth a dedicated alarm specifically because this account's Lambda
  # concurrency limit in eu-central-1 is only 10 and fully unreserved (see
  # reports/03-cicd-hardening.md) — throttling is a real, documented risk
  # here, not a hypothetical edge case.
  alarm_name          = "${var.project}-${var.environment}-status-checker-throttles"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "Throttles"
  namespace           = "AWS/Lambda"
  period              = 300
  statistic           = "Sum"
  threshold           = 1
  alarm_description   = "The status-checker Lambda was throttled — likely account-wide concurrency contention, not a code bug."
  treat_missing_data  = "notBreaching"
  alarm_actions       = [var.sns_topic_arn]

  dimensions = {
    FunctionName = aws_lambda_function.checker.function_name
  }
}
