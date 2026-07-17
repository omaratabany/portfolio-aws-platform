output "website_endpoint" {
  description = "Public HTTP endpoint of the static status page"
  value       = "http://${aws_s3_bucket_website_configuration.site.website_endpoint}"
}
