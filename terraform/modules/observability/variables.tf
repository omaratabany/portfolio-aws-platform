variable "project" {
  description = "Project name used as prefix for all resource names and tags"
  type        = string
}

variable "environment" {
  description = "Deployment environment (dev or prod)"
  type        = string
}

variable "lambda_function_name" {
  description = "Name of the Lambda function to monitor"
  type        = string
}

variable "log_retention_days" {
  description = "Number of days to retain Lambda logs in CloudWatch"
  type        = number
  default     = 14
}

variable "error_threshold" {
  description = "Number of Lambda errors in evaluation period before alarm triggers"
  type        = number
  default     = 1
}

variable "duration_threshold_ms" {
  description = "Lambda duration threshold in milliseconds before alarm triggers"
  type        = number
  default     = 2000
}