output "databases" {
  value = [for m in module.database : m.name]
}

output "warehouses" {
  value = [for m in module.warehouse : m.name]
}

output "access_roles" {
  value = module.rbac.access_roles
}

output "functional_roles" {
  value = module.rbac.functional_roles
}

# Handoff values for bootstrap/aws phase two. Sensitive, so never printed in CI.
output "s3_trust" {
  sensitive = true
  value     = var.s3_integration.enabled ? module.s3_integration[0].trust : null
}
