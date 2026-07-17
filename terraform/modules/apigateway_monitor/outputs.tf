output "api_endpoint" {
  description = "Base URL of the status API Gateway HTTP endpoint"
  value       = aws_apigatewayv2_api.monitor.api_endpoint
}
