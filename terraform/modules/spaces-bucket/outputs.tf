output "name" {
  description = "The name of the bucket"
  value       = digitalocean_spaces_bucket.this.name
}

output "urn" {
  description = "The URN of the bucket"
  value       = digitalocean_spaces_bucket.this.urn
}

output "bucket_domain_name" {
  description = "The bucket domain name (for S3 API access)"
  value       = digitalocean_spaces_bucket.this.bucket_domain_name
}

output "endpoint" {
  description = "The endpoint URL for the bucket"
  value       = "https://${var.region}.digitaloceanspaces.com"
}
