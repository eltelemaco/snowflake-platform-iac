variable "database" {
  type = string
}

variable "schema" {
  type = string
}

variable "name" {
  type = string
}

variable "columns" {
  description = "Ordered column definitions."
  type = list(object({
    name     = string
    type     = string
    nullable = optional(bool, true)
    comment  = optional(string)
  }))

  validation {
    condition     = length(var.columns) > 0
    error_message = "A table needs at least one column."
  }
}

variable "comment" {
  type    = string
  default = null
}
