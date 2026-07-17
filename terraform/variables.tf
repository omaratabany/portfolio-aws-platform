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

variable "alert_email" {
  description = "Email address that receives status-change and budget alerts"
  type        = string
  default     = "omar@atabany.com"
}

variable "monitor_targets" {
  description = "Sites the status monitor checks on a schedule"
  type = list(object({
    name = string
    url  = string
  }))
  default = [
    {
      name = "atabany.net"
      url  = "https://atabany.net"
    }
  ]
}

