# Two separate execution roles, not one shared role: checker writes and
# publishes alerts, api only ever reads. Scoping them separately means a
# bug or compromise in the read-only api function can't write data or send
# SNS messages, and vice versa.

resource "aws_iam_role" "checker_exec" {
  name = "${var.project}-${var.environment}-status-checker-exec"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { Service = "lambda.amazonaws.com" }
        Action    = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy" "checker_dynamodb_write" {
  name = "${var.project}-${var.environment}-status-checker-dynamodb"
  role = aws_iam_role.checker_exec.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:PutItem",
          "dynamodb:GetItem"
        ]
        Resource = var.table_arn
      }
    ]
  })
}

resource "aws_iam_role_policy" "checker_sns_publish" {
  name = "${var.project}-${var.environment}-status-checker-sns"
  role = aws_iam_role.checker_exec.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "sns:Publish"
        Resource = var.sns_topic_arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "checker_basic_execution" {
  role       = aws_iam_role.checker_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "checker_ssm_read" {
  name = "${var.project}-${var.environment}-status-checker-ssm"
  role = aws_iam_role.checker_exec.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "ssm:GetParameter"
        Resource = var.ssm_parameter_arn
      }
    ]
  })
}

resource "aws_iam_role" "api_exec" {
  name = "${var.project}-${var.environment}-status-api-exec"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { Service = "lambda.amazonaws.com" }
        Action    = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy" "api_dynamodb_read" {
  name = "${var.project}-${var.environment}-status-api-dynamodb"
  role = aws_iam_role.api_exec.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:Query"
        ]
        Resource = var.table_arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "api_basic_execution" {
  role       = aws_iam_role.api_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "api_ssm_read" {
  name = "${var.project}-${var.environment}-status-api-ssm"
  role = aws_iam_role.api_exec.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "ssm:GetParameter"
        Resource = var.ssm_parameter_arn
      }
    ]
  })
}
