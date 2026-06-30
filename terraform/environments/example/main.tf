# =============================================================================
# Heimdall - Example Environment
# =============================================================================
# Management node and observability infrastructure for a DigitalOcean VPC.
#
# This configuration creates:
#   - Management droplet (Prometheus, Grafana, Loki, Alertmanager)
#   - Log retention Spaces bucket
#   - Cloud firewall with secure defaults
#
# Prerequisites:
#   - Existing VPC (set vpc_name in terraform.tfvars)
#   - SSH key added to DigitalOcean account
#   - Spaces access keys generated
#
# See CUSTOMIZATION.md for a step-by-step deployment guide.
# =============================================================================

terraform {
  required_version = ">= 1.0.0"

  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "~> 2.0"
    }
  }

  # Remote state backend (recommended for team/production use).
  # Uncomment and fill in your values before running terraform apply.
  # See CUSTOMIZATION.md for the full remote state setup guide.
  # backend "s3" {
  #   endpoint                    = "<region>.digitaloceanspaces.com"
  #   key                         = "terraform/<project_name>/terraform.tfstate"
  #   bucket                      = "<project_name>-terraform-state"
  #   region                      = "us-east-1"  # Required by provider; ignored by DO Spaces
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
# Locals
# =============================================================================

locals {
  management_name = "${var.project_name}-management"
  log_bucket_name = var.log_bucket_name != "" ? var.log_bucket_name : "${var.project_name}-logs-${var.region}"
}

# =============================================================================
# Data Sources
# =============================================================================

data "digitalocean_vpc" "main" {
  name = var.vpc_name
}

data "digitalocean_droplets" "vpc_nodes" {
  filter {
    key    = "vpc_uuid"
    values = [data.digitalocean_vpc.main.id]
  }
}

# =============================================================================
# Management Node
# =============================================================================

module "management_node" {
  source = "../../modules/droplet"

  name             = local.management_name
  region           = var.region
  size             = var.management_node_size
  image            = "ubuntu-24-04-x64"
  vpc_uuid         = data.digitalocean_vpc.main.id
  ssh_fingerprints = [var.ssh_fingerprint]
  tags             = ["management", "monitoring", var.project_name]
}

# =============================================================================
# Log Retention Bucket
# =============================================================================

module "log_retention_bucket" {
  source = "../../modules/spaces-bucket"

  name          = local.log_bucket_name
  region        = var.region
  acl           = "private"
  force_destroy = false
}

# =============================================================================
# Firewall - Management Node
# =============================================================================
#
# Default: Tailscale-only access (most secure)
#   - SSH (22) restricted to ssh_allowed_ips for initial setup and emergencies
#   - All management ports (Grafana, Prometheus, Loki) accessible only over Tailscale
#
# When enable_public_grafana = true:
#   - HTTP (80) opened for Let's Encrypt certificate renewal
#   - HTTPS (443) opened for public Grafana access
# =============================================================================

module "management_firewall" {
  source = "../../modules/firewall"

  name        = "${var.project_name}-management-firewall"
  droplet_ids = [module.management_node.id]
  tags        = []

  inbound_rules = concat(
    [
      {
        protocol         = "tcp"
        port_range       = "22"
        source_addresses = var.ssh_allowed_ips
      }
    ],
    # VPC-internal traffic: Prometheus scraping (9090), Loki ingestion (3100), Alertmanager (9093)
    [
      {
        protocol         = "tcp"
        port_range       = "9090"
        source_addresses = [data.digitalocean_vpc.main.ip_range]
      },
      {
        protocol         = "tcp"
        port_range       = "3100"
        source_addresses = [data.digitalocean_vpc.main.ip_range]
      },
      {
        protocol         = "tcp"
        port_range       = "9093"
        source_addresses = [data.digitalocean_vpc.main.ip_range]
      }
    ],
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
# Ansible Inventory (auto-generated)
# =============================================================================

resource "local_file" "ansible_inventory" {
  content = templatefile("${path.module}/templates/inventory.yml.tpl", {
    management_name       = local.management_name
    management_ip         = module.management_node.ipv4_address
    management_private_ip = module.management_node.ipv4_address_private
    vpc_nodes             = data.digitalocean_droplets.vpc_nodes.droplets
  })
  filename = "${path.module}/../../../ansible/inventory/production.yml"
}
