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

  reserved_concurrent_executions = 5

  tracing_config {
    mode = "Active"
  }

  environment {
    variables = {
      TABLE_NAME     = var.table_name
      SSM_PARAM_NAME = var.ssm_parameter_name
    }
  }

  depends_on = [aws_cloudwatch_log_group.status_api]
}

resource "aws_cloudwatch_log_group" "status_api" {
  # See the matching comment in modules/lambda_checker/main.tf — literal
  # string, not a reference, because of the depends_on ordering above.
  name              = "/aws/lambda/${var.project}-${var.environment}-status-api"
  retention_in_days = 14
}
