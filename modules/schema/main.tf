resource "snowflake_schema" "this" {
  database = var.database
  name     = var.name
  comment  = var.comment
}
