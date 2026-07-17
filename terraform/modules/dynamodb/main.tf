resource "aws_dynamodb_table" "uptime_checks" {
  name         = "${var.project}-${var.environment}-uptime-checks"
  billing_mode = "PROVISIONED"

  # Deliberately provisioned, not PAY_PER_REQUEST: the AWS always-free tier
  # (25 WCU / 25 RCU) only applies to provisioned capacity. On-demand mode
  # has no equivalent ongoing free allowance. 1/1 is far more than this
  # workload needs (~288 writes/day from a 5-minute check interval).
  read_capacity  = 1
  write_capacity = 1

  hash_key  = "target"
  range_key = "sk"

  attribute {
    name = "target"
    type = "S"
  }

  attribute {
    name = "sk"
    type = "S"
  }
}
