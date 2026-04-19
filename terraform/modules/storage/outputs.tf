output "bucket_id" {
  description = "the name of the S3 data bucket"
  value       = aws_s3_bucket.data.id
}

output "bucket_arn" {
  description = "the ARN of the S3 data bucket"
  value       = aws_s3_bucket.data.arn
}
