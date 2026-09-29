variable "name" {
  type = string
}

variable "credit_quota" {
  description = "Credits per period before the suspend trigger fires."
  type        = number
}

variable "frequency" {
  type    = string
  default = "MONTHLY"
}

variable "start_timestamp" {
  description = "When the monitoring period starts. The provider requires it together with frequency; a fixed value keeps plans deterministic."
  type        = string
  default     = "2026-10-01 00:00"
}

variable "notify_triggers" {
  description = "Percent-of-quota thresholds that send a notification."
  type        = set(number)
  default     = [50, 75, 90]
}

variable "suspend_trigger" {
  description = "Percent of quota at which assigned warehouses are suspended after running queries finish."
  type        = number
  default     = 100
}

variable "suspend_immediate_trigger" {
  description = "Percent of quota at which assigned warehouses are suspended immediately. Null = unused."
  type        = number
  default     = 110
}

variable "grant_to_roles" {
  description = "Roles given MONITOR and MODIFY on the monitor, e.g. TF_DEPLOYER so the pipeline can attach it to warehouses and detect drift."
  type        = set(string)
  default     = []
}
