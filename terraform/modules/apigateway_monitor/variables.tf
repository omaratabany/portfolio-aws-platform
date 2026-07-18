variable "project" {
  description = "project used in resource naming and tagging"
  type        = string
}

variable "environment" {
  description = "deployment environment"
  type        = string
}

variable "lambda_function_name" {
  description = "Name of the status-api Lambda function"
  type        = string
}

variable "lambda_invoke_arn" {
  description = "Invoke ARN of the status-api Lambda function"
  type        = string
}

variable "sns_topic_arn" {
  description = "ARN of the shared status-alerts SNS topic, used for this API's 5xx alarm"
  type        = string
}
