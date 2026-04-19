variable "project" {
  description = "project name used as prefx for all resource names and tags"
  type        = string

}

variable "environment" {
  description = "Deployment environment (dev or prod)"
  type        = string
}

variable "bucket_arn" {
  description = "ARN of S3 data bucket the Lambda function is allowed to write to"
  type        = string
}
