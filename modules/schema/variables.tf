variable "database" {
  description = "Database the schema lives in (already env-prefixed)."
  type        = string
}

variable "name" {
  type = string
}

variable "comment" {
  type    = string
  default = null
}
