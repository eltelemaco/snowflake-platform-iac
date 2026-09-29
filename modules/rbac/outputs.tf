output "access_roles" {
  value = sort(keys(snowflake_account_role.access))
}

output "functional_roles" {
  value = sort(keys(snowflake_account_role.functional))
}
