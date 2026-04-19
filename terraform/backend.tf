terraform {
  backend "s3" {
    bucket         = "portfolio-tfstate-637423316787"
    key            = "portfolio-platform/terraform.tfstate"
    region         = "eu-central-1"
    dynamodb_table = "portfolio-tfstate-lock"
    encrypt        = true
  }
}
