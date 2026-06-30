#!/bin/bash
# =============================================================================
# Deployment Script — manual (non-Ansible) path
# =============================================================================
# Syncs docker/monitoring/ to the management node and starts the stack.
# Prefer the Ansible playbooks for production deployments; use this script
# for quick iterations or when Ansible is not available.
#
# Usage:
#   export PROJECT_NAME=my-project   # must match terraform project_name
#   ./scripts/deploy.sh [management_node_ip]
# =============================================================================
set -e

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REMOTE_USER="root"

if [ -z "${PROJECT_NAME:-}" ]; then
    echo "Error: PROJECT_NAME environment variable not set."
    echo "Set it to your project name (matches the Terraform project_name variable):"
    echo "  export PROJECT_NAME=my-project"
    exit 1
fi

REMOTE_DIR="/opt/${PROJECT_NAME}-monitoring"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}Deployment — ${PROJECT_NAME}${NC}"
echo "=================================================="

# Get the Droplet IP from Terraform output (falls back to manual arg)
cd "$PROJECT_ROOT/terraform/environments/example"
DROPLET_IP=$(terraform output -raw management_node_ip 2>/dev/null || echo "")

if [ -n "$1" ]; then
    DROPLET_IP="$1"
fi

if [ -z "$DROPLET_IP" ]; then
    echo -e "${RED}Error: Could not retrieve management_node_ip from Terraform output.${NC}"
    echo "Make sure you have run 'terraform apply' first, or pass the IP directly:"
    echo "  $0 <management_node_ip>"
    exit 1
fi

echo -e "Target: ${YELLOW}$REMOTE_USER@$DROPLET_IP${NC}"
echo ""

# Sync monitoring configuration files
echo -e "${GREEN}Syncing monitoring configuration...${NC}"
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
echo -e "${GREEN}Starting monitoring stack...${NC}"
ssh "$REMOTE_USER@$DROPLET_IP" "cd $REMOTE_DIR && docker compose pull && docker compose up -d"

echo ""
echo -e "${GREEN}Deployment complete!${NC}"
echo "=================================================="
echo ""
echo "Access your monitoring stack (via Tailscale):"
echo "  Grafana:      http://$DROPLET_IP:3000"
echo "  Prometheus:   http://$DROPLET_IP:9090"
echo "  Alertmanager: http://$DROPLET_IP:9093"
echo ""
echo "Next steps:"
echo "  1. Install Tailscale: scp scripts/setup-tailscale.sh $REMOTE_USER@$DROPLET_IP:/tmp/ && ssh $REMOTE_USER@$DROPLET_IP 'bash /tmp/setup-tailscale.sh'"
echo "  2. Deploy agents to other servers: ansible-playbook -i ansible/inventory/production.yml ansible/playbooks/deploy-agents.yml"
echo ""
