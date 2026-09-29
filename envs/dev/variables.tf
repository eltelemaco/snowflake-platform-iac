variable "databases" {
  type = map(object({
    data_retention_days = optional(number, 1)
    comment             = optional(string)
  }))
}

variable "warehouses" {
  type = map(object({
    size                  = optional(string, "XSMALL")
    auto_suspend_seconds  = optional(number, 60)
    statement_timeout_sec = optional(number, 3600)
    comment               = optional(string)
  }))
}

variable "functional_roles" {
  type = map(set(string))
}

variable "network_policy_allowed_ips" {
  type    = list(string)
  default = []
}

variable "demo_users" {
  type    = map(string)
  default = {}
}
