variable "project" {
  description = "project used in resource naming and tagging"
  type        = string
}

variable "environment" {
  description = "deployment environment"
  type        = string
}

variable "alert_email" {
  description = "Email address that receives status-change and budget alerts"
  type        = string
}
