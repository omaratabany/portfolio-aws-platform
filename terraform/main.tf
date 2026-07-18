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

# --- Status monitor (Phase 1 of the cloud infra project) ---
# Deliberately separate from the ingest pipeline above: different concern,
# different audience, own IAM roles, own API. Module order: budget (applies
# first, independent of everything else) → dynamodb/sns_alerts →
# iam_monitor → lambda_checker/lambda_api → eventbridge/apigateway_monitor.

module "budget" {
  source = "./modules/budget"

  project     = var.project
  alert_email = var.alert_email
}

module "dynamodb" {
  source = "./modules/dynamodb"

  project     = var.project
  environment = var.environment
}

module "sns_alerts" {
  source = "./modules/sns_alerts"

  project     = var.project
  environment = var.environment
  alert_email = var.alert_email
}

module "ssm_config" {
  source = "./modules/ssm_config"

  project         = var.project
  environment     = var.environment
  monitor_targets = var.monitor_targets
}

module "iam_monitor" {
  source = "./modules/iam_monitor"

  project           = var.project
  environment       = var.environment
  table_arn         = module.dynamodb.table_arn
  sns_topic_arn     = module.sns_alerts.topic_arn
  ssm_parameter_arn = module.ssm_config.parameter_arn
  aws_region        = var.aws_region
}

module "lambda_checker" {
  source = "./modules/lambda_checker"

  project            = var.project
  environment        = var.environment
  exec_role_arn      = module.iam_monitor.checker_exec_role_arn
  table_name         = module.dynamodb.table_name
  sns_topic_arn      = module.sns_alerts.topic_arn
  ssm_parameter_name = module.ssm_config.parameter_name
}

module "lambda_api" {
  source = "./modules/lambda_api"

  project            = var.project
  environment        = var.environment
  exec_role_arn      = module.iam_monitor.api_exec_role_arn
  table_name         = module.dynamodb.table_name
  ssm_parameter_name = module.ssm_config.parameter_name
}

module "eventbridge" {
  source = "./modules/eventbridge"

  project               = var.project
  environment           = var.environment
  checker_function_name = module.lambda_checker.function_name
  checker_function_arn  = module.lambda_checker.function_arn
}

module "apigateway_monitor" {
  source = "./modules/apigateway_monitor"

  project              = var.project
  environment          = var.environment
  lambda_function_name = module.lambda_api.function_name
  lambda_invoke_arn    = module.lambda_api.invoke_arn
}

module "site" {
  source = "./modules/site"

  project     = var.project
  environment = var.environment
  account_id  = data.aws_caller_identity.current.account_id
  api_base    = module.apigateway_monitor.api_endpoint
}

# --- Phase 2: scope the CI role down from the Resource="*" grant it
# started with to exactly the three function ARNs it deploys code to.
# Declared last on purpose — it depends on every Lambda module above.

module "iam_ci_policy" {
  source = "./modules/iam_ci_policy"

  project                  = var.project
  environment              = var.environment
  github_actions_role_name = module.iam.github_actions_role_name
  lambda_function_arns = [
    module.lambda.function_arn,
    module.lambda_checker.function_arn,
    module.lambda_api.function_arn,
  ]
}