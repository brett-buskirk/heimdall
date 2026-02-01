# =============================================================================
# Droplet Module
# =============================================================================
# Creates a DigitalOcean droplet with optional VPC placement and tagging.
# Designed for reuse across management, application, and client workloads.
# =============================================================================

resource "digitalocean_droplet" "this" {
  image    = var.image
  name     = var.name
  region   = var.region
  size     = var.size
  vpc_uuid = var.vpc_uuid
  ssh_keys = var.ssh_fingerprints
  tags     = var.tags

  # Ensure droplet is created before any dependent resources
  lifecycle {
    create_before_destroy = true
  }
}
