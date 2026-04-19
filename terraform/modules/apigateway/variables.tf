variable "project" {
  description = "Project name used as prefix for all resource names and tags"
  type        = string
}

variable "environment" {
  description = "Deployment environment (dev or prod)"
  type        = string
}

variable "lambda_function_name" {
  description = "Name of the Lambda function API Gateway will invoke"
  type        = string
}

variable "lambda_invoke_arn" {
  description = "Invoke ARN of the Lambda function used by API Gateway integration"
  type        = string
}

variable "account_id" {
  description = "AWS account ID used for Lambda permission resource"
  type        = string
}

variable "aws_region" {
  description = "AWS region used for Lambda permission resource"
  type        = string
}