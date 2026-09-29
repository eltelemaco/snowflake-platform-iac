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
