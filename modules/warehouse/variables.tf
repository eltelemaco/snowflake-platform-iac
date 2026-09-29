variable "name" {
  description = "Warehouse name, already env-prefixed by the caller (e.g. DEV_LOAD_WH)."
  type        = string
}

variable "size" {
  type    = string
  default = "XSMALL"
}

variable "auto_suspend_seconds" {
  description = "Idle time before suspend. 60 is the minimum that avoids paying the 60s minimum twice."
  type        = number
  default     = 60
}

variable "statement_timeout_in_seconds" {
  description = "Hard cap on any single statement, a cost guardrail against runaway queries."
  type        = number
  default     = 3600
}

variable "comment" {
  type    = string
  default = null
}
