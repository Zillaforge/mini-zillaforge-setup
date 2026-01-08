output "server_id" {
  value = zillaforge_server.this.id
}

output "floating_ip_id" {
  value = local.floating_ip_id
}

output "floating_ip_address" {
  value = local.floating_ip_address
}

output "server_name" {
  value = zillaforge_server.this.name
}
