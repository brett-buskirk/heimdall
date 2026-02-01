# =============================================================================
# Variables - Production Environment
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
# Infrastructure Configuration
# -----------------------------------------------------------------------------

variable "region" {
  description = "DigitalOcean region"
  type        = string
  default     = "nyc3"
}

variable "vpc_name" {
  description = "Name of the existing VPC to deploy into"
  type        = string
  default     = "rcj-vpc-nyc3"
}

variable "ssh_fingerprint" {
  description = "SSH key fingerprint registered with DigitalOcean"
  type        = string
}

# -----------------------------------------------------------------------------
# Management Node Configuration
# -----------------------------------------------------------------------------

variable "management_node_size" {
  description = "Droplet size for the management node"
  type        = string
  default     = "s-2vcpu-4gb"  # ~$24/mo - good for monitoring stack
}

variable "log_bucket_name" {
  description = "Name for the log retention Spaces bucket"
  type        = string
  default     = "rcj-logs-nyc3"
}

# -----------------------------------------------------------------------------
# Security Configuration
# -----------------------------------------------------------------------------

variable "ssh_allowed_ips" {
  description = "List of IP addresses/CIDRs allowed to SSH (use 0.0.0.0/0 for any)"
  type        = list(string)
  default     = ["0.0.0.0/0", "::/0"]  # Consider restricting in production
}

variable "enable_public_grafana" {
  description = "Enable public HTTP/HTTPS access to Grafana (set false if using Tailscale)"
  type        = bool
  default     = false  # Secure by default - use Tailscale
}

# -----------------------------------------------------------------------------
# Monitoring Configuration
# -----------------------------------------------------------------------------

variable "grafana_domain" {
  description = "Domain name for Grafana (e.g., grafana.rcjourney.cloud)"
  type        = string
  default     = ""
}

variable "alert_email" {
  description = "Email address for alert notifications"
  type        = string
  default     = ""
}
