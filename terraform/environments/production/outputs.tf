# =============================================================================
# Outputs - Production Environment
# =============================================================================

output "management_node_ip" {
  description = "Public IP address of the management node"
  value       = module.management_node.ipv4_address
}

output "management_node_private_ip" {
  description = "Private (VPC) IP address of the management node"
  value       = module.management_node.ipv4_address_private
}

output "log_bucket_name" {
  description = "Name of the log retention bucket"
  value       = module.log_retention_bucket.name
}

output "log_bucket_endpoint" {
  description = "Endpoint URL for the log bucket"
  value       = module.log_retention_bucket.endpoint
}

output "ssh_command" {
  description = "SSH command to connect to the management node"
  value       = "ssh root@${module.management_node.ipv4_address}"
}

output "vpc_ip_range" {
  description = "IP range of the VPC (for reference)"
  value       = data.digitalocean_vpc.rcj_vpc.ip_range
}

output "vpc_droplets" {
  description = "List of droplets in the VPC (for agent deployment)"
  value = [
    for d in data.digitalocean_droplets.vpc_droplets.droplets : {
      name       = d.name
      private_ip = d.ipv4_address_private
      public_ip  = d.ipv4_address
    }
  ]
}

# Grafana URL (depends on access method)
output "grafana_url" {
  description = "URL to access Grafana"
  value = var.enable_public_grafana && var.grafana_domain != "" ? (
    "https://${var.grafana_domain}"
  ) : (
    "http://${module.management_node.ipv4_address}:3000 (via Tailscale or SSH tunnel)"
  )
}
