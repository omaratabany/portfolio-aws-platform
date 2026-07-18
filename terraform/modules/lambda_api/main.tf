data "archive_file" "status_api" {
  type        = "zip"
  source_file = "${path.root}/../functions/api.py"
  output_path = "${path.root}/../functions/api.zip"
}

resource "aws_lambda_function" "status_api" {
  function_name    = "${var.project}-${var.environment}-status-api"
  role             = var.exec_role_arn
  handler          = "api.handler"
  runtime          = "python3.12"
  timeout          = 10
  filename         = data.archive_file.status_api.output_path
  source_code_hash = data.archive_file.status_api.output_base64sha256

  # See the reserved_concurrent_executions note in modules/lambda/main.tf.

  tracing_config {
    mode = "Active"
  }

  environment {
    variables = {
      TABLE_NAME     = var.table_name
      SSM_PARAM_NAME = var.ssm_parameter_name
    }
  }

  depends_on = [aws_cloudwatch_log_group.status_api]
}

resource "aws_cloudwatch_log_group" "status_api" {
  # See the matching comment in modules/lambda_checker/main.tf — literal
  # string, not a reference, because of the depends_on ordering above.
  name              = "/aws/lambda/${var.project}-${var.environment}-status-api"
  retention_in_days = 14
}

# See the matching comment block in modules/lambda_checker/main.tf for why
# alarms live here rather than in the shared `observability` module, and
# why this reuses var.sns_topic_arn rather than a second topic.

resource "aws_cloudwatch_metric_alarm" "api_errors" {
  alarm_name          = "${var.project}-${var.environment}-status-api-errors"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 300
  statistic           = "Sum"
  threshold           = 1
  alarm_description   = "The status-api Lambda itself failed to run (crash, timeout, throttle) — different from the site being down."
  treat_missing_data  = "notBreaching"
  alarm_actions       = [var.sns_topic_arn]
  ok_actions          = [var.sns_topic_arn]

  dimensions = {
    FunctionName = aws_lambda_function.status_api.function_name
  }
}

resource "aws_cloudwatch_metric_alarm" "api_duration" {
  alarm_name          = "${var.project}-${var.environment}-status-api-duration"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "Duration"
  namespace           = "AWS/Lambda"
  period              = 300
  # Maximum, not Average — see the matching comment in
  # modules/lambda_checker/main.tf. A single slow /status or /history
  # call getting averaged in with faster requests could otherwise stay
  # under threshold indefinitely.
  statistic          = "Maximum"
  threshold          = 8000 # ms — well under the 10s function timeout
  alarm_description  = "The status-api Lambda is running unusually long."
  treat_missing_data = "notBreaching"
  alarm_actions      = [var.sns_topic_arn]

  dimensions = {
    FunctionName = aws_lambda_function.status_api.function_name
  }
}

resource "aws_cloudwatch_metric_alarm" "api_throttles" {
  # See the matching comment in modules/lambda_checker/main.tf — Errors
  # doesn't cover throttled invocations, and this account's Lambda
  # concurrency limit (10, fully unreserved) makes throttling a real risk
  # here, not a hypothetical one.
  alarm_name          = "${var.project}-${var.environment}-status-api-throttles"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "Throttles"
  namespace           = "AWS/Lambda"
  period              = 300
  statistic           = "Sum"
  threshold           = 1
  alarm_description   = "The status-api Lambda was throttled — likely account-wide concurrency contention, not a code bug."
  treat_missing_data  = "notBreaching"
  alarm_actions       = [var.sns_topic_arn]

  dimensions = {
    FunctionName = aws_lambda_function.status_api.function_name
  }
}
