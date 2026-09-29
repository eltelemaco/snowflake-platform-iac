# Break-glass stack. Snowflake only lets ACCOUNTADMIN create resource monitors
# or attach one to the account, and that cannot be delegated. So this stack is
# applied by a human (never by CI) and CI only reads it for drift detection.
# Cost governance is therefore the one place where a control is deliberately
# harder to change than the rest of the platform.

module "monitor" {
  source   = "../../modules/resource_monitor"
  for_each = var.monitors

  name           = each.key
  credit_quota   = each.value.credit_quota
  grant_to_roles = [var.deployer_role]
}

resource "snowflake_execute" "account_monitor" {
  count = var.account_monitor == null ? 0 : 1

  execute = "ALTER ACCOUNT SET RESOURCE_MONITOR = ${module.monitor[var.account_monitor].name}"
  revert  = "ALTER ACCOUNT UNSET RESOURCE_MONITOR"
  query   = "SHOW PARAMETERS LIKE 'RESOURCE_MONITOR' IN ACCOUNT"
}

# Attaching a monitor to a warehouse needs MODIFY on the ACCOUNT, which the
# pipeline role deliberately does not have. Applied after the env stacks.
resource "snowflake_execute" "warehouse_monitor" {
  for_each = var.warehouse_monitors

  execute = "ALTER WAREHOUSE ${each.key} SET RESOURCE_MONITOR = ${module.monitor[each.value].name}"
  revert  = "ALTER WAREHOUSE ${each.key} UNSET RESOURCE_MONITOR"
  query   = "SHOW WAREHOUSES LIKE '${each.key}'"
}
