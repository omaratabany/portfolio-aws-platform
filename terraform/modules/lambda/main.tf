data "archive_file" "ingest" {
  type        = "zip"
  source_file = "${path.root}/../functions/ingest.py"
  output_path = "${path.root}/../functions/ingest.zip"
}

resource "aws_lambda_function" "ingest" {
  function_name    = "${var.project}-${var.environment}-ingest"
  role             = var.lambda_exec_role_arn
  handler          = "ingest.handler"
  runtime          = "python3.12"
  filename         = data.archive_file.ingest.output_path
  source_code_hash = data.archive_file.ingest.output_base64sha256

  # Hard ceiling on concurrent invocations (CKV_AWS_115) — cost control as
  # much as reliability: a traffic spike or retry storm can't run away
  # past this regardless of what triggers it.
  reserved_concurrent_executions = 5

  tracing_config {
    mode = "Active"
  }

  environment {
    variables = {
      BUCKET_NAME = var.bucket_id
    }
  }
}