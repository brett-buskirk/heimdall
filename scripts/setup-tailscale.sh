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
echo "Tailscale is installed. Run the following command:"
echo ""
echo "  sudo tailscale up"
echo ""
echo "This will give you a URL to authenticate."
echo "After authentication, your management node will be"
echo "accessible via Tailscale at:"
echo ""
echo "  http://\$(hostname):3000  (Grafana)"
echo "  http://\$(hostname):9090  (Prometheus)"
echo ""
echo "You can also use the Tailscale IP shown after 'tailscale up'"
echo "=================================================="
