# =============================================================================
# Spaces Bucket Module
# =============================================================================
# Creates a DigitalOcean Spaces bucket with optional lifecycle rules for
# log retention and archival. Designed for observability data storage.
# =============================================================================

terraform {
  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "~> 2.0"
    }
  }
}

resource "digitalocean_spaces_bucket" "this" {
  name          = var.name
  region        = var.region
  acl           = var.acl
  force_destroy = var.force_destroy
}

# Lifecycle rule for automatic log expiration
# Note: DO Spaces lifecycle rules are managed via the Spaces API, not Terraform
# This resource creates the bucket; lifecycle policies should be configured
# via s3cmd or the DO console. See README for instructions.
