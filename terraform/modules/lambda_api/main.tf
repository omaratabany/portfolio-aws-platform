data "archive_file" "status_api" {
  type        = "zip"
  source_file = "${path.root}/../functions/api.py"
  output_path = "${path.root}/../functions/api.zip"
}

resource "aws_lambda_function" "status_api" {
  function_name    = "${var.project}-${var.environment}-status-api"
  role             = var.exec_role_arn
  handler          = "api.handler"
  runtime          = "python3.12"
  timeout          = 10
  filename         = data.archive_file.status_api.output_path
  source_code_hash = data.archive_file.status_api.output_base64sha256

  environment {
    variables = {
      TABLE_NAME = var.table_name
      TARGETS    = var.targets_json
    }
  }
}
