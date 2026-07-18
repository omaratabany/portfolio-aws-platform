# A read-only IAM identity for an *external* consumer (the homelab's two
# Grafana instances, on-prem, not running in AWS) to query CloudWatch —
# the AWS-side half of Phase 4's "hybrid observability" stretch goal.
# Separate module from `iam_security_baseline`: that one is about this
# account's own security posture, this one is a scoped credential handed
# to something outside the account entirely.
#
# Deliberately IAM user + access key, not a role: there's no AWS-side
# compute (EC2/Lambda) for Grafana to assume a role from — it's running
# on-prem, so a long-lived key is the only mechanism CloudWatch's Grafana
# data source supports here. The access key itself is created out-of-band
# via the AWS CLI (see reports/04-observability.md), never through
# Terraform, so the secret is never written into Terraform state.

resource "aws_iam_user" "grafana_reader" {
  name = "${var.project}-${var.environment}-grafana-cloudwatch-reader"
}

data "aws_iam_policy_document" "cloudwatch_read_only" {
  statement {
    sid    = "CloudWatchMetricsReadOnly"
    effect = "Allow"
    actions = [
      "cloudwatch:GetMetricData",
      "cloudwatch:GetMetricStatistics",
      "cloudwatch:ListMetrics",
      "cloudwatch:DescribeAlarms",
      "cloudwatch:ListDashboards",
      "cloudwatch:GetDashboard",
    ]
    resources = ["*"]
  }

  # Grafana's CloudWatch data source uses these two to populate its
  # region picker and resource-tag-based dimension filters — standard,
  # documented requirements for the plugin, not an over-broad grant.
  statement {
    sid    = "GrafanaCloudWatchPluginSupport"
    effect = "Allow"
    actions = [
      "ec2:DescribeRegions",
      "tag:GetResources",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_user_policy" "cloudwatch_read_only" {
  name   = "cloudwatch-read-only"
  user   = aws_iam_user.grafana_reader.name
  policy = data.aws_iam_policy_document.cloudwatch_read_only.json
}
