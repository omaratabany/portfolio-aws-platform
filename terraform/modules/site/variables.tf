variable "project" {
  description = "project used in resource naming and tagging"
  type        = string
}

variable "environment" {
  description = "deployment environment"
  type        = string
}

variable "account_id" {
  description = "AWS account ID, used to make the bucket name globally unique"
  type        = string
}

variable "api_base" {
  description = "Base URL of the status API, baked into the page at deploy time"
  type        = string
}
