output "monitors" {
  value = [for m in module.monitor : m.name]
}
