resource "snowflake_table" "this" {
  database = var.database
  schema   = var.schema
  name     = var.name
  comment  = var.comment

  dynamic "column" {
    for_each = var.columns
    content {
      name     = column.value.name
      type     = column.value.type
      nullable = column.value.nullable
      comment  = column.value.comment
    }
  }
}
