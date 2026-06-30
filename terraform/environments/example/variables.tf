# =============================================================================
# Variables - Example Environment
# =============================================================================

# -----------------------------------------------------------------------------
# DigitalOcean Authentication
# -----------------------------------------------------------------------------

variable "do_token" {
  description = "DigitalOcean API token"
  type        = string
  sensitive   = true
}

variable "spaces_access_id" {
  description = "DigitalOcean Spaces access key ID"
  type        = string
  sensitive   = true
}

variable "spaces_secret_key" {
  description = "DigitalOcean Spaces secret key"
  type        = string
  sensitive   = true
}

# -----------------------------------------------------------------------------
# Project
# -----------------------------------------------------------------------------

variable "project_name" {
  description = "Short identifier for this deployment (e.g. 'acme', 'myco'). Prefixes all resource names and tags. Use lowercase letters, numbers, and hyphens only."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]{0,30}[a-z0-9]$", var.project_name))
    error_message = "project_name must be 2-32 characters, lowercase alphanumeric and hyphens, not starting or ending with a hyphen."
  }
}

# -----------------------------------------------------------------------------
# Infrastructure Configuration
# -----------------------------------------------------------------------------

variable "region" {
  description = "DigitalOcean region slug (e.g. 'nyc3', 'ams3', 'sfo3')"
  type        = string
  default     = "nyc3"
}

variable "vpc_name" {
  description = "Name of the existing VPC to deploy the management node into"
  type        = string
}

variable "ssh_fingerprint" {
  description = "SSH key fingerprint registered with DigitalOcean (from: doctl compute ssh-key list)"
  type        = string
}

# -----------------------------------------------------------------------------
# Management Node Configuration
# -----------------------------------------------------------------------------

variable "management_node_size" {
  description = "Droplet size for the management node. s-2vcpu-4gb (~$24/mo) is the recommended minimum for the full monitoring stack."
  type        = string
  default     = "s-2vcpu-4gb"
}

variable "log_bucket_name" {
  description = "Name of the Spaces bucket for log retention. Leave empty to auto-derive as '<project_name>-logs-<region>'."
  type        = string
  default     = ""
}

# -----------------------------------------------------------------------------
# Security Configuration
# -----------------------------------------------------------------------------

variable "ssh_allowed_ips" {
  description = <<-EOT
    List of IP addresses/CIDRs allowed to SSH to the management node.
    Restrict this to known IPs - do not use ["0.0.0.0/0", "::/0"] in production.
    Example: ["203.0.113.10/32", "198.51.100.0/24"]
  EOT
  type        = list(string)

  validation {
    condition     = length(var.ssh_allowed_ips) > 0
    error_message = "ssh_allowed_ips must contain at least one entry. Set it to your known IPs."
  }
}

variable "enable_public_grafana" {
  description = "Expose Grafana publicly over HTTP/HTTPS. Leave false when using Tailscale (recommended)."
  type        = bool
  default     = false
}

# -----------------------------------------------------------------------------
# Monitoring Configuration
# -----------------------------------------------------------------------------

variable "grafana_domain" {
  description = "Domain name for Grafana (e.g. 'grafana.yourdomain.com'). Only used when enable_public_grafana = true."
  type        = string
  default     = ""
}

variable "alert_email" {
  description = "Email address for alert notifications"
  type        = string
  default     = ""
}
