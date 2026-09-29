resource "snowflake_resource_monitor" "this" {
  name                      = var.name
  credit_quota              = var.credit_quota
  frequency                 = var.frequency
  start_timestamp           = var.start_timestamp
  notify_triggers           = var.notify_triggers
  suspend_trigger           = var.suspend_trigger
  suspend_immediate_trigger = var.suspend_immediate_trigger

}

resource "snowflake_grant_privileges_to_account_role" "access" {
  for_each          = var.grant_to_roles
  account_role_name = each.value
  privileges        = ["MONITOR", "MODIFY"]
  on_account_object {
    object_type = "RESOURCE MONITOR"
    object_name = snowflake_resource_monitor.this.name
  }
}
