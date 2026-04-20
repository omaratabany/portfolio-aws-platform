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

module "iam" {
  source = "./modules/iam"

  project     = var.project
  environment = var.environment
  bucket_arn  = module.storage.bucket_arn

}

module "lambda" {
  source = "./modules/lambda"

  project              = var.project
  environment          = var.environment
  bucket_id            = module.storage.bucket_id
  lambda_exec_role_arn = module.iam.lambda_exec_role_arn
}
module "apigateway" {
  source = "./modules/apigateway"

  project              = var.project
  environment          = var.environment
  lambda_function_name = module.lambda.function_name
  lambda_invoke_arn    = module.lambda.invoke_arn
  account_id           = data.aws_caller_identity.current.account_id
  aws_region           = var.aws_region
}

module "observability" {
  source = "./modules/observability"

  project              = var.project
  environment          = var.environment
  lambda_function_name = module.lambda.function_name
}