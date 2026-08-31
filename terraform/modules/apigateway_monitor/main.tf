# A separate HTTP API from the ingest pipeline's, not new routes bolted
# onto it. The ingest API and the status API are unrelated concerns with
# different audiences (internal event ingestion vs. a public status page)
# — coupling them for convenience would make each harder to reason about
# and change independently later.

resource "aws_apigatewayv2_api" "monitor" {
  name          = "${var.project}-${var.environment}-status-api"
  protocol_type = "HTTP"

  cors_configuration {
    allow_origins = ["*"]
    allow_methods = ["GET"]
  }
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.monitor.id
  name        = "$default"
  auto_deploy = true

  default_route_settings {
    throttling_rate_limit  = 10
    throttling_burst_limit = 20
  }
}

resource "aws_apigatewayv2_integration" "lambda" {
  api_id                 = aws_apigatewayv2_api.monitor.id
  integration_type       = "AWS_PROXY"
  integration_uri        = var.lambda_invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "status" {
  api_id    = aws_apigatewayv2_api.monitor.id
  route_key = "GET /status"
  target    = "integrations/${aws_apigatewayv2_integration.lambda.id}"
}

resource "aws_apigatewayv2_route" "history" {
  api_id    = aws_apigatewayv2_api.monitor.id
  route_key = "GET /history/{target}"
  target    = "integrations/${aws_apigatewayv2_integration.lambda.id}"
}

resource "aws_lambda_permission" "apigw" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = var.lambda_function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.monitor.execution_arn}/*/*"
}

# functions/api.py deliberately catches every exception and returns a
# well-formed {"statusCode": 500, ...} proxy response rather than letting
# Lambda crash — that keeps the client-facing error shape consistent, but
# it also means a DynamoDB/SSM failure is a *successful* Lambda invocation
# from AWS's point of view, so it never trips the AWS/Lambda Errors metric.
# This alarm therefore combines three signals via metric math into one
# CloudWatch alarm rather than three separate ones: the API Gateway layer
# (catches the caught-and-returned 500s — HTTP APIs emit this metric
# automatically, no access logging needed), plus the Lambda's own
# Errors and Throttles metrics (catches a crash or account-wide
# concurrency contention before the Lambda layer even runs). Merged
# specifically to stay well clear of the "10 alarms always free" tier
# after an 85%-of-free-tier usage alert — see reports/04-observability.md.
resource "aws_cloudwatch_metric_alarm" "api_failures" {
  alarm_name          = "${var.project}-${var.environment}-status-api-failures"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  threshold           = 1
  alarm_description   = "GET /status or GET /history/{target} failed — a 5xx response, a Lambda error, or a throttle. Check the API Gateway 5xx and Lambda Errors/Throttles metrics to tell which."
  treat_missing_data  = "notBreaching"
  alarm_actions       = [var.sns_topic_arn]
  ok_actions          = [var.sns_topic_arn]

  metric_query {
    id          = "failures"
    expression  = "gw5xx + errors + throttles"
    label       = "5xx + Errors + Throttles"
    return_data = true
  }

  metric_query {
    id = "gw5xx"
    metric {
      metric_name = "5xx"
      namespace   = "AWS/ApiGateway"
      period      = 300
      stat        = "Sum"
      dimensions = {
        ApiId = aws_apigatewayv2_api.monitor.id
      }
    }
  }

  metric_query {
    id = "errors"
    metric {
      metric_name = "Errors"
      namespace   = "AWS/Lambda"
      period      = 300
      stat        = "Sum"
      dimensions = {
        FunctionName = var.lambda_function_name
      }
    }
  }

  metric_query {
    id = "throttles"
    metric {
      metric_name = "Throttles"
      namespace   = "AWS/Lambda"
      period      = 300
      stat        = "Sum"
      dimensions = {
        FunctionName = var.lambda_function_name
      }
    }
  }
}
