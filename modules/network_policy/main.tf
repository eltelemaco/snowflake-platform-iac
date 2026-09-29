resource "snowflake_network_policy" "this" {
  name            = var.name
  allowed_ip_list = var.allowed_ip_list
  comment         = var.comment
}
