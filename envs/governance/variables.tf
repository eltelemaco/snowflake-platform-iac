variable "monitors" {
  type = map(object({
    credit_quota = number
  }))
}

variable "account_monitor" {
  type    = string
  default = null
}

variable "warehouse_monitors" {
  type    = map(string)
  default = {}
}
