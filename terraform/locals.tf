locals {
  common_tags = {
    Project     = var.project
    Environment = var.environment
    ManagedBy   = "terraform"
    Owner       = "omar.atabany"
    Region      = var.aws_region
    Repository  = "github.com/omaratabany/portfolio-aws-platform"
  }
}
