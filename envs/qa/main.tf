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
}

module "platform" {
  source = "../../stacks/platform"

  environment                = "qa"
  databases                  = var.databases
  warehouses                 = var.warehouses
  functional_roles           = var.functional_roles
  network_policy_allowed_ips = var.network_policy_allowed_ips
  demo_users                 = var.demo_users
  s3_integration             = var.s3_integration
  aws_account_id             = var.aws_account_id
}

output "s3_trust" {
  description = "Values for bootstrap/aws phase two: terraform output -json s3_trust"
  sensitive   = true
  value       = module.platform.s3_trust
}
