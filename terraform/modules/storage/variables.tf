variable "project" {
  description = "Project name used as prefix for all resource names and tags"
  type        = string
}

variable "environment" {
  description = "Deployment environment (dev or prod)"
  type        = string
}

variable "account_id" {
  description = "AWS account ID used to ensure globally unique bucket naming"
  type        = string
}
