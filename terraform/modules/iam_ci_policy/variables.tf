variable "project" {
  description = "project used in resource naming"
  type        = string
}

variable "environment" {
  description = "deployment environment"
  type        = string
}

variable "github_actions_role_name" {
  description = "Name of the IAM role assumed by GitHub Actions via OIDC"
  type        = string
}

variable "lambda_function_arns" {
  description = "ARNs of the Lambda functions CI is allowed to deploy code to"
  type        = list(string)
}
