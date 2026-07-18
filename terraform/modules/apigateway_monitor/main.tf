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
# from AWS's point of view, so it never trips the AWS/Lambda Errors alarm
# in modules/lambda_api. This alarm watches the API Gateway layer instead,
# where a caught-and-returned 500 still shows up as a 5xx response —
# HTTP APIs emit this metric automatically, no access logging needed.
resource "aws_cloudwatch_metric_alarm" "api_5xx" {
  alarm_name          = "${var.project}-${var.environment}-status-api-5xx"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "5xx"
  namespace           = "AWS/ApiGateway"
  period              = 300
  statistic           = "Sum"
  threshold           = 1
  alarm_description   = "GET /status or GET /history/{target} returned a 5xx — includes application-level errors the Lambda catches and returns as a formatted 500, which the Lambda Errors alarm can't see."
  treat_missing_data  = "notBreaching"
  alarm_actions       = [var.sns_topic_arn]

  dimensions = {
    ApiId = aws_apigatewayv2_api.monitor.id
  }
}
