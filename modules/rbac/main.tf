# Access-role / functional-role model.
#   access roles     hold privileges on objects (one per database and level, one per warehouse)
#   functional roles hold *no* privileges, only inherit access roles; users get these
# Everything rolls up to SYSADMIN so the account admin can always see it.

locals {
  db_access_roles = merge(
    { for db in var.databases : "${db}_RO" => { db = db, level = "RO" } },
    { for db in var.databases : "${db}_RW" => { db = db, level = "RW" } },
  )
  wh_access_roles = { for wh in var.warehouses : "${wh}_USAGE" => wh }

  known_access_roles = toset(concat(keys(local.db_access_roles), keys(local.wh_access_roles)))

  functional_grants = merge([
    for fr, members in var.functional_roles : {
      for m in members : "${fr}|${m}" => { functional = fr, access = m }
    }
  ]...)
}

resource "snowflake_account_role" "access" {
  for_each = local.known_access_roles
  name     = each.key
  comment  = "Access role. Managed by Terraform."
}

resource "snowflake_account_role" "functional" {
  for_each = var.functional_roles
  name     = each.key
  comment  = "Functional role. Inherits access roles only. Managed by Terraform."
}

# --- database privileges ------------------------------------------------------

resource "snowflake_grant_privileges_to_account_role" "db_usage" {
  for_each          = local.db_access_roles
  account_role_name = snowflake_account_role.access[each.key].name
  privileges        = each.value.level == "RW" ? ["USAGE", "CREATE SCHEMA"] : ["USAGE"]
  on_account_object {
    object_type = "DATABASE"
    object_name = each.value.db
  }
}

resource "snowflake_grant_privileges_to_account_role" "future_schema_usage" {
  for_each          = local.db_access_roles
  account_role_name = snowflake_account_role.access[each.key].name
  privileges        = ["USAGE"]
  on_schema {
    future_schemas_in_database = each.value.db
  }
}

resource "snowflake_grant_privileges_to_account_role" "future_table_read" {
  for_each          = local.db_access_roles
  account_role_name = snowflake_account_role.access[each.key].name
  privileges        = ["SELECT"]
  on_schema_object {
    future {
      object_type_plural = "TABLES"
      in_database        = each.value.db
    }
  }
}

resource "snowflake_grant_privileges_to_account_role" "future_view_read" {
  for_each          = local.db_access_roles
  account_role_name = snowflake_account_role.access[each.key].name
  privileges        = ["SELECT"]
  on_schema_object {
    future {
      object_type_plural = "VIEWS"
      in_database        = each.value.db
    }
  }
}

resource "snowflake_grant_privileges_to_account_role" "future_table_write" {
  for_each          = { for k, v in local.db_access_roles : k => v if v.level == "RW" }
  account_role_name = snowflake_account_role.access[each.key].name
  privileges        = ["INSERT", "UPDATE", "DELETE", "TRUNCATE"]
  on_schema_object {
    future {
      object_type_plural = "TABLES"
      in_database        = each.value.db
    }
  }
}

# --- warehouse privileges -----------------------------------------------------

resource "snowflake_grant_privileges_to_account_role" "wh_usage" {
  for_each          = local.wh_access_roles
  account_role_name = snowflake_account_role.access[each.key].name
  privileges        = ["USAGE", "MONITOR"]
  on_account_object {
    object_type = "WAREHOUSE"
    object_name = each.value
  }
}

# --- hierarchy ----------------------------------------------------------------

# <DB>_RW inherits <DB>_RO so write access always implies read access.
resource "snowflake_grant_account_role" "rw_inherits_ro" {
  for_each         = { for k, v in local.db_access_roles : k => v if v.level == "RW" }
  role_name        = snowflake_account_role.access["${each.value.db}_RO"].name
  parent_role_name = snowflake_account_role.access[each.key].name
}

resource "snowflake_grant_account_role" "access_to_functional" {
  for_each         = local.functional_grants
  role_name        = snowflake_account_role.access[each.value.access].name
  parent_role_name = snowflake_account_role.functional[each.value.functional].name

  lifecycle {
    precondition {
      condition     = contains(local.known_access_roles, each.value.access)
      error_message = "Functional role ${each.value.functional} references unknown access role ${each.value.access}."
    }
  }
}

resource "snowflake_grant_account_role" "functional_to_sysadmin" {
  for_each         = var.functional_roles
  role_name        = snowflake_account_role.functional[each.key].name
  parent_role_name = "SYSADMIN"
}
