variable "environment" {
  description = "Upper-case environment prefix, e.g. DEV. Names the integration."
  type        = string
}

variable "database" {
  description = "Database that gets the LANDING schema and external stage."
  type        = string
}

variable "bucket" {
  type = string
}

variable "prefix" {
  description = "Key prefix inside the bucket this environment may read (no slashes)."
  type        = string
}

variable "role_arn" {
  description = "IAM role Snowflake assumes. Contains the AWS account ID, so callers pass it as a sensitive value."
  type        = string
  sensitive   = true
}

variable "directory_enabled" {
  description = "Enable the stage's directory table (list files with DIRECTORY(@stage)). Changing it replaces the stage."
  type        = bool
  default     = false
}
