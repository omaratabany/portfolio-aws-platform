variable "project" {
    description = "Project name used as prefix for all resource names and tags"
    type = string
}

variable "environment" {
    description = "Deployment environment (dev or prod)"
    type = string
}

variable "bucket_id" {
    description = "Name of the S3 data bucket passed to lambda as environement variable"
    type = string
}

variable "lambda_exec_role_arn" {
    description = "ARN of the IAM role the lambda function will assume at runtime"
    type = string
}