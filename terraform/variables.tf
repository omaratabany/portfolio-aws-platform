variable "aws_region" {
  description = "AWS Region for all resources"
  type        = string
  default     = "eu-central-1"
}
variable "project" {
  description = "project used in resource naming and tagging"
  type        = string
  default     = "portfolio-platform"
}

variable "environment" {
  description = "deployment environment"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "prod"], var.environment)
    error_message = "Environment must be dev or prod"
  }
}

