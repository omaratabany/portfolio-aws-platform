variable "project" {
  description = "project used in resource naming and tagging"
  type        = string
}

variable "environment" {
  description = "deployment environment"
  type        = string
}

variable "table_arn" {
  description = "ARN of the UptimeChecks DynamoDB table"
  type        = string
}

variable "sns_topic_arn" {
  description = "ARN of the SNS topic used for status-change alerts"
  type        = string
}

variable "ssm_parameter_arn" {
  description = "ARN of the SSM parameter holding the monitor target list"
  type        = string
}
