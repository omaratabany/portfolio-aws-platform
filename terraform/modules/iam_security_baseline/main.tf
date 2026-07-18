# Account-wide security posture, not scoped to any one pipeline —
# that's why this is its own module rather than folded into `iam` (the
# ingest CI role) or `iam_monitor` (the status-monitor Lambda roles).
# See reports/05-security-baseline.md for the reasoning behind each
# setting below, and for what's deliberately NOT here (GuardDuty,
# Security Hub, AWS Config — all bill per-resource/per-finding).

# Free, account-wide: continuously scans for resource policies (S3,
# IAM roles, SNS topics, ...) that grant access to a principal outside
# this account. Expected to flag module.site's public bucket policy —
# that's correct, not a bug (same "accepted" pattern as the Checkov S3
# findings in reports/03-cicd-hardening.md).
resource "aws_accessanalyzer_analyzer" "account" {
  analyzer_name = "${var.project}-${var.environment}-analyzer"
  type          = "ACCOUNT"
}

# CIS AWS Foundations Benchmark asks for a 90-day max_password_age.
# Deliberately left unset (no forced expiration) instead: NIST 800-63B
# (the more current federal password guidance) recommends against
# mandatory periodic rotation for a well-chosen password, since forced
# rotation empirically pushes people toward predictable incremented
# passwords (Password1, Password2, ...) rather than stronger ones.
# Length + complexity + reuse prevention below is the actual defense;
# see ADR-19 in reports/05-security-baseline.md.
resource "aws_iam_account_password_policy" "this" {
  minimum_password_length        = 14
  require_lowercase_characters   = true
  require_uppercase_characters   = true
  require_numbers                = true
  require_symbols                = true
  allow_users_to_change_password = true
  password_reuse_prevention      = 5
}
