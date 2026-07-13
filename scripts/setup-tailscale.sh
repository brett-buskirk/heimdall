#!/bin/bash
# =============================================================================
# Tailscale Setup Script
# =============================================================================
# Installs and configures Tailscale on the management node
# =============================================================================
set -e

echo "🔐 Installing Tailscale..."

# Install Tailscale (staged to avoid piping curl directly to shell)
curl -fsSL https://tailscale.com/install.sh -o /tmp/tailscale-install.sh
sh /tmp/tailscale-install.sh
rm -f /tmp/tailscale-install.sh

# Start Tailscale and get auth URL
echo ""
echo "=================================================="
echo "Tailscale is installed. Now authenticate this node:"
echo ""
echo "  sudo tailscale up"
echo ""
echo "Follow the printed URL to authenticate."
echo ""
echo "To reach the stack, the device you browse from must ALSO be on"
echo "the same tailnet: install Tailscale there and log in with the"
echo "same account. Then get this node's Tailscale IP:"
echo ""
echo "  tailscale ip -4"
echo ""
echo "and open Grafana from your device at:"
echo ""
echo "  http://<that-tailscale-ip>:3000   (Grafana — the stack UI)"
echo ""
echo "Grafana is the only service exposed over Tailscale. Prometheus,"
echo "Loki, and Alertmanager stay VPC-internal and are viewed through"
echo "Grafana (dashboards, Explore, and the Alerting UI)."
echo "=================================================="
