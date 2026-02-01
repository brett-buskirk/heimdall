#!/bin/bash
# =============================================================================
# RCJ Infrastructure - Deployment Script
# =============================================================================
# Deploys monitoring files to the management node and starts the stack
# =============================================================================
set -e

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REMOTE_USER="root"
REMOTE_DIR="/opt/rcj-monitoring"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}🏔️  RCJ Infrastructure Deployment${NC}"
echo "=================================================="

# Get the Droplet IP from Terraform output
cd "$PROJECT_ROOT/terraform/environments/production"
DROPLET_IP=$(terraform output -raw management_node_ip 2>/dev/null || echo "")

if [ -z "$DROPLET_IP" ]; then
    echo -e "${RED}Error: Could not retrieve management_node_ip from Terraform output.${NC}"
    echo "Make sure you have run 'terraform apply' first."
    echo ""
    echo "Or provide the IP manually:"
    echo "  $0 <management_node_ip>"
    exit 1
fi

if [ -n "$1" ]; then
    DROPLET_IP="$1"
fi

echo -e "Target: ${YELLOW}$REMOTE_USER@$DROPLET_IP${NC}"
echo ""

# Sync monitoring configuration files
echo -e "${GREEN}📦 Syncing monitoring configuration...${NC}"
rsync -avz --exclude '.git' \
    --exclude 'terraform' \
    --exclude 'ansible' \
    --exclude 'scripts' \
    --exclude '*.md' \
    "$PROJECT_ROOT/docker/monitoring/" "$REMOTE_USER@$DROPLET_IP:$REMOTE_DIR/"

# Copy environment file if it exists
if [ -f "$PROJECT_ROOT/docker/monitoring/.env" ]; then
    rsync -avz "$PROJECT_ROOT/docker/monitoring/.env" "$REMOTE_USER@$DROPLET_IP:$REMOTE_DIR/.env"
else
    echo -e "${YELLOW}Warning: No .env file found. Copy .env.example and configure it.${NC}"
fi

# Start the monitoring stack
echo -e "${GREEN}🚀 Starting monitoring stack...${NC}"
ssh "$REMOTE_USER@$DROPLET_IP" "cd $REMOTE_DIR && docker compose pull && docker compose up -d"

echo ""
echo -e "${GREEN}✅ Deployment complete!${NC}"
echo "=================================================="
echo ""
echo "Access your monitoring stack:"
echo "  Grafana:      http://$DROPLET_IP:3000"
echo "  Prometheus:   http://$DROPLET_IP:9090"
echo "  Alertmanager: http://$DROPLET_IP:9093"
echo ""
echo "Next steps:"
echo "  1. Install Tailscale: ssh $REMOTE_USER@$DROPLET_IP 'curl -fsSL https://tailscale.com/install.sh | sh'"
echo "  2. Deploy agents to other servers: ansible-playbook -i inventory/production.yml playbooks/deploy-agents.yml"
echo ""
