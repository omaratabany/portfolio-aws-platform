variable "project" {
  description = "project used in resource naming and tagging"
  type        = string
}

variable "environment" {
  description = "deployment environment"
  type        = string
}

variable "checker_function_name" {
  description = "Name of the checker Lambda function"
  type        = string
}

variable "checker_function_arn" {
  description = "ARN of the checker Lambda function"
  type        = string
}
