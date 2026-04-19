output "api_endpoint" {
  description = "Base URL of the API Gateway endpoint"
  value       = aws_apigatewayv2_stage.default.invoke_url
}