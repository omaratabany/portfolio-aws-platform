provider "aws" {
  region = var.aws_region

  default_tags {
    tags = local.common_tags
  }
}
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

module "storage" {
  source = "./modules/storage"

  project     = var.project
  environment = var.environment
  account_id  = data.aws_caller_identity.current.account_id
}
