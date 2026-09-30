terraform {
  required_version = ">= 1.10"

  required_providers {
    snowflake = {
      source  = "snowflakedb/snowflake"
      version = "2.21.0"
    }
  }

  # Partial config: bucket comes from -backend-config in CI (kept out of the repo).
  backend "s3" {}
}

# Auth-agnostic on purpose. Credentials arrive through SNOWFLAKE_* environment
# variables: OIDC token in CI, key-pair on a laptop. Same code either way.
provider "snowflake" {
  role = "TF_DEPLOYER"

  # snowflake_table is a preview resource in provider 2.x: plans work without this,
  # but apply fails ("snowflake_table_resource is currently a preview feature").
  preview_features_enabled = ["snowflake_table_resource"]
}

module "platform" {
  source = "../../stacks/platform"

  environment                = "prod"
  databases                  = var.databases
  warehouses                 = var.warehouses
  functional_roles           = var.functional_roles
  network_policy_allowed_ips = var.network_policy_allowed_ips
  demo_users                 = var.demo_users
  s3_integration             = var.s3_integration
  aws_account_id             = var.aws_account_id
  schemas                    = var.schemas
  tables                     = var.tables
}

output "s3_trust" {
  description = "Values for bootstrap/aws phase two: terraform output -json s3_trust"
  sensitive   = true
  value       = module.platform.s3_trust
}
