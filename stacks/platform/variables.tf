variable "environment" {
  description = "Environment. Prefixes every object so envs can share one Snowflake account (see README: production uses account-per-env)."
  type        = string

  validation {
    condition     = contains(["dev", "qa", "prod"], var.environment)
    error_message = "environment must be dev, qa or prod."
  }
}

variable "databases" {
  description = "Logical database names. Created as <ENV>_<NAME>."
  type = map(object({
    data_retention_days = optional(number, 1)
    comment             = optional(string)
  }))
}

variable "warehouses" {
  description = "Logical warehouse names. Created as <ENV>_<NAME>."
  type = map(object({
    size                  = optional(string, "XSMALL")
    auto_suspend_seconds  = optional(number, 60)
    statement_timeout_sec = optional(number, 3600)
    comment               = optional(string)
  }))
}

variable "functional_roles" {
  description = "Logical functional role -> logical access roles (RAW_RW, LOAD_WH_USAGE, ...). Prefixed with <ENV>_ here."
  type        = map(set(string))
}

variable "network_policy_allowed_ips" {
  description = "Allow-list for the human-user network policy. Empty = no policy is created."
  type        = list(string)
  default     = []
}

variable "demo_users" {
  description = "Human demo users (logical functional role => login suffix). Only created when a network policy is set."
  type        = map(string)
  default     = {}
}

variable "s3_integration" {
  description = "S3 landing zone. The bucket and IAM role are created by bootstrap/aws."
  type = object({
    enabled = optional(bool, false)
    bucket  = optional(string, "")
  })
  default = {}
}

variable "aws_account_id" {
  description = "AWS account that owns the landing bucket roles. Sensitive so it stays out of plans and PR comments (this repo is public)."
  type        = string
  default     = ""
  sensitive   = true

  validation {
    condition     = !var.s3_integration.enabled || (var.aws_account_id != "" && var.s3_integration.bucket != "")
    error_message = "s3_integration.enabled requires aws_account_id and s3_integration.bucket."
  }
}

variable "schemas" {
  description = "Schemas to create, keyed by schema name. `database` is a logical key of var.databases (e.g. RAW)."
  type = map(object({
    database = string
    comment  = optional(string)
  }))
  default = {}
}

variable "tables" {
  description = "Tables to create, keyed by table name. `database` and `schema` are keys of var.databases and var.schemas."
  type = map(object({
    database = string
    schema   = string
    comment  = optional(string)
    columns = list(object({
      name     = string
      type     = string
      nullable = optional(bool, true)
      comment  = optional(string)
    }))
  }))
  default = {}
}
