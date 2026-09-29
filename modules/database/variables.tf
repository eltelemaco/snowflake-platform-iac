variable "name" {
  description = "Database name, already env-prefixed by the caller (e.g. DEV_RAW)."
  type        = string
}

variable "data_retention_time_in_days" {
  description = "Time Travel retention. Enterprise edition allows up to 90."
  type        = number
  default     = 1
}

variable "comment" {
  type    = string
  default = null
}
