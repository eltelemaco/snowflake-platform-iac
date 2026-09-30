locals {
  env    = upper(var.environment)
  prefix = "${local.env}_"

  database_names  = { for k, v in var.databases : k => "${local.prefix}${k}" }
  warehouse_names = { for k, v in var.warehouses : k => "${local.prefix}${k}" }

  tags = "Managed by Terraform (${var.environment})"
}

module "database" {
  source   = "../../modules/database"
  for_each = var.databases

  name                        = local.database_names[each.key]
  data_retention_time_in_days = each.value.data_retention_days
  comment                     = coalesce(each.value.comment, local.tags)
}

module "warehouse" {
  source   = "../../modules/warehouse"
  for_each = var.warehouses

  name                         = local.warehouse_names[each.key]
  size                         = each.value.size
  auto_suspend_seconds         = each.value.auto_suspend_seconds
  statement_timeout_in_seconds = each.value.statement_timeout_sec
  comment                      = coalesce(each.value.comment, local.tags)
}

module "rbac" {
  source = "../../modules/rbac"

  # Passing module outputs (not the locals) makes grants wait for the objects.
  databases  = toset([for m in module.database : m.name])
  warehouses = toset([for m in module.warehouse : m.name])

  functional_roles = {
    for role, members in var.functional_roles :
    "${local.prefix}${role}" => toset([for m in members : "${local.prefix}${m}"])
  }
}

module "network_policy" {
  source = "../../modules/network_policy"
  count  = length(var.network_policy_allowed_ips) > 0 ? 1 : 0

  name            = "${local.prefix}HUMAN_USERS"
  allowed_ip_list = var.network_policy_allowed_ips
  comment         = "${local.tags}. Human users only: CI service users are exempt by design."
}

resource "snowflake_user" "demo" {
  for_each = length(var.network_policy_allowed_ips) > 0 ? var.demo_users : {}

  name           = "${local.prefix}${each.value}"
  comment        = "Demo human user. ${local.tags}"
  network_policy = module.network_policy[0].name
  disabled       = true # demo object: exists to show policy attachment, cannot log in
}

resource "snowflake_grant_account_role" "demo_user_role" {
  for_each = snowflake_user.demo

  role_name = "${local.prefix}${each.key}"
  user_name = each.value.name

  depends_on = [module.rbac]
}

module "s3_integration" {
  source = "../../modules/s3_integration"
  count  = var.s3_integration.enabled ? 1 : 0

  environment = local.env
  database    = module.database["RAW"].name
  bucket      = var.s3_integration.bucket
  prefix      = var.environment

  directory_enabled = var.s3_integration.directory_enabled
  role_arn          = "arn:aws:iam::${var.aws_account_id}:role/snowflake-s3-${var.environment}"

  # The RAW_RW future grants must exist before the LANDING schema is created.
  depends_on = [module.rbac]

}

# Engineers may read from the stage. Read-only by design: the IAM role is read-only too.
resource "snowflake_grant_privileges_to_account_role" "landing_stage_usage" {
  count = var.s3_integration.enabled ? 1 : 0

  account_role_name = "${local.prefix}RAW_RW"
  privileges        = ["USAGE"]
  on_schema_object {
    object_type = "STAGE"
    object_name = module.s3_integration[0].stage_fully_qualified_name
  }

  depends_on = [module.rbac]
}

# Schemas and tables. The database-level future grants in module.rbac already cover
# them, so a new schema or table is readable/writable by the right roles the moment it
# exists. No per-object grants to write. depends_on makes the grants come first.
module "schema" {
  source   = "../../modules/schema"
  for_each = var.schemas

  database = module.database[each.value.database].name
  name     = each.key
  comment  = coalesce(each.value.comment, local.tags)

  depends_on = [module.rbac]
}

module "table" {
  source   = "../../modules/table"
  for_each = var.tables

  database = module.database[each.value.database].name
  schema   = module.schema[each.value.schema].name
  name     = each.key
  columns  = each.value.columns
  comment  = coalesce(each.value.comment, local.tags)
}
