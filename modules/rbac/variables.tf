variable "databases" {
  description = "Database names to create access roles for. Each gets <DB>_RO and <DB>_RW."
  type        = set(string)
}

variable "warehouses" {
  description = "Warehouse names to create usage roles for. Each gets <WH>_USAGE."
  type        = set(string)
}

variable "functional_roles" {
  description = <<-EOT
    Functional (job-function) roles and the access roles they inherit, e.g.
    { DEV_DATA_ENGINEER = ["DEV_RAW_RW", "DEV_LOAD_WH_USAGE"] }.
    Users are only ever granted functional roles, never access roles.
  EOT
  type        = map(set(string))
}
