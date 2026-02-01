# =============================================================================
# Firewall Module
# =============================================================================
# Creates a DigitalOcean Cloud Firewall with configurable inbound/outbound
# rules. Designed to be secure by default with explicit allow rules.
# =============================================================================

resource "digitalocean_firewall" "this" {
  name        = var.name
  droplet_ids = var.droplet_ids
  tags        = var.tags

  # Dynamic inbound rules
  dynamic "inbound_rule" {
    for_each = var.inbound_rules
    content {
      protocol         = inbound_rule.value.protocol
      port_range       = inbound_rule.value.port_range
      source_addresses = inbound_rule.value.source_addresses
      source_tags      = lookup(inbound_rule.value, "source_tags", null)
    }
  }

  # Allow all outbound TCP
  outbound_rule {
    protocol              = "tcp"
    port_range            = "1-65535"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }

  # Allow all outbound UDP
  outbound_rule {
    protocol              = "udp"
    port_range            = "1-65535"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }

  # Allow outbound ICMP (ping)
  outbound_rule {
    protocol              = "icmp"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }
}
