# =============================================================================
# RCJ Infrastructure - Production Environment
# =============================================================================
# Management node and observability infrastructure for rcj-vpc-nyc3
# 
# This configuration creates:
#   - Management droplet (Prometheus, Grafana, Loki, Alertmanager)
#   - Log retention Spaces bucket
#   - Cloud firewall with secure defaults
#
# Prerequisites:
#   - Existing VPC (rcj-vpc-nyc3)
#   - SSH key added to DigitalOcean account
#   - Spaces access keys generated
# =============================================================================

terraform {
  required_version = ">= 1.0.0"

  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "~> 2.0"
    }
  }

  # Optional: Remote state backend (recommended for team/production use)
  # backend "s3" {
  #   endpoint                    = "nyc3.digitaloceanspaces.com"
  #   key                         = "terraform/rcj-infra/terraform.tfstate"
  #   bucket                      = "rcj-terraform-state"
  #   region                      = "us-east-1"  # Required but ignored by DO
  #   skip_credentials_validation = true
  #   skip_metadata_api_check     = true
  #   skip_region_validation      = true
  # }
}

provider "digitalocean" {
  token             = var.do_token
  spaces_access_id  = var.spaces_access_id
  spaces_secret_key = var.spaces_secret_key
}

# =============================================================================
# Data Sources
# =============================================================================

# Look up existing VPC by name
data "digitalocean_vpc" "rcj_vpc" {
  name = var.vpc_name
}

# Look up existing droplets for firewall rules (metrics scraping)
data "digitalocean_droplets" "vpc_droplets" {
  filter {
    key    = "vpc_uuid"
    values = [data.digitalocean_vpc.rcj_vpc.id]
  }
}

# =============================================================================
# Management Node
# =============================================================================

module "management_node" {
  source = "../../modules/droplet"

  name             = "rcj-management"
  region           = var.region
  size             = var.management_node_size
  image            = "ubuntu-24-04-x64"
  vpc_uuid         = data.digitalocean_vpc.rcj_vpc.id
  ssh_fingerprints = [var.ssh_fingerprint]
  tags             = ["management", "monitoring", "rcj-infra"]
}

# =============================================================================
# Log Retention Bucket
# =============================================================================

module "log_retention_bucket" {
  source = "../../modules/spaces-bucket"

  name          = var.log_bucket_name
  region        = var.region
  acl           = "private"
  force_destroy = false  # Protect log data from accidental deletion
}

# =============================================================================
# Firewall - Management Node
# =============================================================================
# 
# Default configuration: Tailscale-only access (most secure)
# - SSH (22) open for initial setup and emergency access
# - All other access via Tailscale mesh network
#
# If var.enable_public_grafana = true:
# - HTTP (80) open for Let's Encrypt certificate renewal
# - HTTPS (443) open for Grafana web UI
# =============================================================================

module "management_firewall" {
  source = "../../modules/firewall"

  name        = "rcj-management-firewall"
  droplet_ids = [module.management_node.id]
  tags        = []

  inbound_rules = concat(
    # Always allow SSH
    [
      {
        protocol         = "tcp"
        port_range       = "22"
        source_addresses = var.ssh_allowed_ips
      }
    ],
    # VPC-internal traffic for metrics/logs (Prometheus scraping, Promtail shipping)
    [
      {
        protocol         = "tcp"
        port_range       = "9090"  # Prometheus
        source_addresses = [data.digitalocean_vpc.rcj_vpc.ip_range]
      },
      {
        protocol         = "tcp"
        port_range       = "3100"  # Loki
        source_addresses = [data.digitalocean_vpc.rcj_vpc.ip_range]
      },
      {
        protocol         = "tcp"
        port_range       = "9093"  # Alertmanager
        source_addresses = [data.digitalocean_vpc.rcj_vpc.ip_range]
      }
    ],
    # Conditionally allow public HTTP/HTTPS for Grafana
    var.enable_public_grafana ? [
      {
        protocol         = "tcp"
        port_range       = "80"
        source_addresses = ["0.0.0.0/0", "::/0"]
      },
      {
        protocol         = "tcp"
        port_range       = "443"
        source_addresses = ["0.0.0.0/0", "::/0"]
      }
    ] : []
  )
}

# =============================================================================
# Outputs for Ansible Integration
# =============================================================================

# Generate Ansible inventory file
resource "local_file" "ansible_inventory" {
  content = templatefile("${path.module}/templates/inventory.yml.tpl", {
    management_ip         = module.management_node.ipv4_address
    management_private_ip = module.management_node.ipv4_address_private
    vpc_droplets          = data.digitalocean_droplets.vpc_droplets.droplets
  })
  filename = "${path.module}/../../../ansible/inventory/production.yml"
}
