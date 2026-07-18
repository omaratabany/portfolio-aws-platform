resource "aws_ssm_parameter" "monitor_targets" {
  name        = "/${var.project}/${var.environment}/status-monitor/targets"
  description = "JSON list of {name, url} objects the status monitor checks — editable without redeploying either Lambda"
  type        = "String"
  value       = jsonencode(var.monitor_targets)
}
