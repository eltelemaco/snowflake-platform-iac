variable "expected_account_id" {
  description = "Guard rail: apply aborts unless the credentials belong to this AWS account. Set via TF_VAR_expected_account_id; never committed."
  type        = string
}

variable "github_sub_prefix" {
  description = "Prefix of the GitHub OIDC `sub` claim. This repo uses the immutable form (owner and repo IDs), see `gh api repos/<repo>/actions/oidc/customization/sub`."
  type        = string
  default     = "repo:eltelemaco@6528831/snowflake-platform-iac@1396665286"
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

variable "snowflake_storage_iam" {
  description = <<-EOT
    Per-environment trust for the Snowflake storage integration roles, from
    `terraform output` of each envs/<env> root once its integration exists:
    { dev = { iam_user_arn = "...", external_id = "..." }, ... }
    While an environment has no entry, its role trusts this AWS account's root,
    a deliberate two-phase handshake because Snowflake only reveals these values
    after the integration is created. Supply it via TF_VAR, never commit it.
  EOT
  type = map(object({
    iam_user_arn = string
    external_id  = string
  }))
  default = {}
}
