variable "expected_account_id" {
  description = "Guard rail: apply aborts unless the credentials belong to this AWS account. Set via TF_VAR_expected_account_id; never committed."
  type        = string
}

variable "github_repo" {
  description = "owner/name of the repo whose workflows may assume the roles."
  type        = string
  default     = "eltelemaco/snowflake-platform-iac"
}

variable "environments" {
  type    = set(string)
  default = ["dev", "qa", "prod"]
}
