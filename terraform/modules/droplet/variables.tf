variable "name" {
  description = "Name of the droplet"
  type        = string
}

variable "region" {
  description = "DigitalOcean region"
  type        = string
}

variable "size" {
  description = "Droplet size slug (e.g., s-2vcpu-4gb)"
  type        = string
  default     = "s-2vcpu-4gb"
}

variable "image" {
  description = "Droplet image slug"
  type        = string
  default     = "ubuntu-24-04-x64"
}

variable "vpc_uuid" {
  description = "UUID of the VPC to place the droplet in"
  type        = string
  default     = null
}

variable "ssh_fingerprints" {
  description = "List of SSH key fingerprints to add to the droplet"
  type        = list(string)
}

variable "tags" {
  description = "Tags to apply to the droplet"
  type        = list(string)
  default     = []
}
