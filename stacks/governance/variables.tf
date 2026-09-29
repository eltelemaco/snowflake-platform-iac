variable "monitors" {
  description = "Resource monitors keyed by name. Credit quotas are per month."
  type = map(object({
    credit_quota = number
  }))
}

variable "account_monitor" {
  description = "Key in `monitors` that guards the whole account. Null = none."
  type        = string
  default     = null
}

variable "deployer_role" {
  description = "Role that receives MONITOR + MODIFY so the pipeline can attach monitors to warehouses and plan for drift."
  type        = string
  default     = "TF_DEPLOYER"
}

variable "warehouse_monitors" {
  description = "Warehouse name => monitor name. Applied AFTER the env stacks (the warehouses must exist)."
  type        = map(string)
  default     = {}
}
