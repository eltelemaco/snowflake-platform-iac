resource "snowflake_warehouse" "this" {
  name                         = var.name
  warehouse_size               = var.size
  auto_suspend                 = var.auto_suspend_seconds
  auto_resume                  = true
  initially_suspended          = true
  statement_timeout_in_seconds = var.statement_timeout_in_seconds
  comment                      = var.comment

  lifecycle {
    # Attaching a monitor needs MODIFY on the ACCOUNT, which the pipeline role
    # deliberately lacks. stacks/governance (ACCOUNTADMIN, manual) owns it.
    ignore_changes = [resource_monitor]
  }
}
