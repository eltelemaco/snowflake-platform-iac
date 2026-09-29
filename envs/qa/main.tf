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
}
