variable "project" {
  description = "project used in resource naming"
  type        = string
}

variable "environment" {
  description = "deployment environment"
  type        = string
}

variable "monitor_targets" {
  description = "Sites the status monitor checks"
  type = list(object({
    name = string
    url  = string
  }))
}
