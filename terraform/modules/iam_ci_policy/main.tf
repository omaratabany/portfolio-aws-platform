# Scoped replacement for the CI role's deploy permissions. The policy
# this replaces (previously defined inline in modules/iam) granted
# lambda:UpdateFunctionCode/GetFunction on Resource "*" plus three S3
# actions that deploy.yml never actually calls — dead permissions nobody
# had audited. This scopes Lambda actions to exactly the three function
# ARNs CI deploys code to, and drops the S3 grant entirely.

resource "aws_iam_role_policy" "github_actions_deploy" {
  name = "${var.project}-${var.environment}-github-actions-deploy"
  role = var.github_actions_role_name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "lambda:UpdateFunctionCode",
          "lambda:GetFunction"
        ]
        Resource = var.lambda_function_arns
      }
    ]
  })
}
