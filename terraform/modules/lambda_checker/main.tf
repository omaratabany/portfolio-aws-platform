data "archive_file" "checker" {
  type        = "zip"
  source_file = "${path.root}/../functions/checker.py"
  output_path = "${path.root}/../functions/checker.zip"
}

resource "aws_lambda_function" "checker" {
  function_name    = "${var.project}-${var.environment}-status-checker"
  role             = var.exec_role_arn
  handler          = "checker.handler"
  runtime          = "python3.12"
  timeout          = 15
  filename         = data.archive_file.checker.output_path
  source_code_hash = data.archive_file.checker.output_base64sha256

  environment {
    variables = {
      TABLE_NAME    = var.table_name
      SNS_TOPIC_ARN = var.sns_topic_arn
      TARGETS       = var.targets_json
    }
  }
}
