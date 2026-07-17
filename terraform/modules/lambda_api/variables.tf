variable "project" {
  description = "project used in resource naming and tagging"
  type        = string
}

variable "environment" {
  description = "deployment environment"
  type        = string
}

variable "exec_role_arn" {
  description = "ARN of the api Lambda's execution role"
  type        = string
}

variable "table_name" {
  description = "Name of the UptimeChecks DynamoDB table"
  type        = string
}

variable "targets_json" {
  description = "JSON-encoded list of {name, url} objects, used to enumerate /status"
  type        = string
}
