resource "snowflake_database" "this" {
  name                        = var.name
  data_retention_time_in_days = var.data_retention_time_in_days
  comment                     = var.comment
}
