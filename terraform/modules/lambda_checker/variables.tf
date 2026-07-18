variable "project" {
  description = "project used in resource naming and tagging"
  type        = string
}

variable "environment" {
  description = "deployment environment"
  type        = string
}

variable "exec_role_arn" {
  description = "ARN of the checker Lambda's execution role"
  type        = string
}

variable "table_name" {
  description = "Name of the UptimeChecks DynamoDB table"
  type        = string
}

variable "sns_topic_arn" {
  description = "ARN of the SNS topic used for status-change alerts"
  type        = string
}

variable "ssm_parameter_name" {
  description = "Name of the SSM parameter holding the JSON-encoded target list"
  type        = string
}
