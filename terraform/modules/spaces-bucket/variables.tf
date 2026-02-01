variable "name" {
  description = "Name of the Spaces bucket"
  type        = string
}

variable "region" {
  description = "DigitalOcean region for the bucket"
  type        = string
}

variable "acl" {
  description = "Access control list (private or public-read)"
  type        = string
  default     = "private"
}

variable "force_destroy" {
  description = "Allow bucket deletion even if it contains objects"
  type        = bool
  default     = false
}
