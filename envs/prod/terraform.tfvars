# PROD: the only file that should differ meaningfully between environments.
databases = {
  RAW       = { data_retention_days = 7 }
  ANALYTICS = { data_retention_days = 7 }
}

warehouses = {
  LOAD_WH = { size = "XSMALL" }
  BI_WH   = { size = "XSMALL" }
}

functional_roles = {
  DATA_ENGINEER = ["RAW_RW", "ANALYTICS_RW", "LOAD_WH_USAGE", "BI_WH_USAGE"]
  ANALYST       = ["ANALYTICS_RO", "BI_WH_USAGE"]
}

# Documentation range (TEST-NET-3). Replace with the corporate egress CIDR.
network_policy_allowed_ips = ["203.0.113.0/24"]
demo_users = {
  ANALYST = "DEMO_ANALYST"
}

# Landing zone: bucket and IAM role come from bootstrap/aws.
s3_integration = {
  enabled = true
  bucket  = "snowflake-platform-iac-landing-8e6407430e"
}

# Demo change: the SALES schema.
schemas = {
  SALES = { database = "RAW", comment = "Order data from the storefront" }
}
