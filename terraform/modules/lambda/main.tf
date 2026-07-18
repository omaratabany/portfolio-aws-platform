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

  # CKV_AWS_115 wants a reserved concurrency ceiling here — attempted,
  # reverted. This account's total Lambda concurrency limit in
  # eu-central-1 is only 10 (not AWS's usual default of 1000), and it's
  # currently entirely unreserved; AWS requires >=10 unreserved at all
  # times, so reserving any amount for any function fails outright
  # without a service quota increase first. See reports/03-cicd-hardening.md.

  tracing_config {
    mode = "Active"
  }

  environment {
    variables = {
      BUCKET_NAME = var.bucket_id
    }
  }
}