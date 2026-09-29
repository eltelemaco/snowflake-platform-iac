terraform {
  required_version = ">= 1.10"

  required_providers {
    snowflake = {
      source  = "snowflakedb/snowflake"
      version = "2.21.0"
    }
  }

  backend "s3" {}
}

# Applied manually as ACCOUNTADMIN. Credentials come from SNOWFLAKE_* env vars.
provider "snowflake" {
  role = "ACCOUNTADMIN"
}

module "governance" {
  source = "../../stacks/governance"

  monitors        = var.monitors
  account_monitor = var.account_monitor

  warehouse_monitors = var.warehouse_monitors
}
