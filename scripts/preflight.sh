#!/bin/bash
# =============================================================================
# Preflight Check — validate the local environment before deploying Heimdall
# =============================================================================
# Checks that required tools are installed and at the right versions, that
# configuration files have been populated from their examples, and that the
# DigitalOcean CLI is authenticated.
#
# Usage:
#   ./scripts/preflight.sh
#
# Exit code 0 = all required checks passed (warnings may still be present).
# Exit code 1 = one or more required checks failed.
# =============================================================================
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m'

FAILURES=0
WARNINGS=0

pass()  { echo -e "  ${GREEN}✓${NC} $1"; }
fail()  { echo -e "  ${RED}✗${NC} $1"; FAILURES=$((FAILURES + 1)); }
warn()  { echo -e "  ${YELLOW}!${NC} $1"; WARNINGS=$((WARNINGS + 1)); }
header(){ echo -e "\n${BOLD}$1${NC}"; }

# =============================================================================
# Tools
# =============================================================================
header "Tools"

# terraform >= 1.0.0
if command -v terraform &>/dev/null; then
    TF_VER=$(terraform version -json 2>/dev/null | grep -o '"terraform_version":"[^"]*"' | grep -o '[0-9][^"]*' || terraform version | grep -oP '[\d.]+' | head -1)
    TF_MAJOR=$(echo "$TF_VER" | cut -d. -f1)
    if [ "${TF_MAJOR}" -ge 1 ]; then
        pass "terraform ${TF_VER}"
    else
        fail "terraform ${TF_VER} — version >= 1.0 required"
    fi
else
    fail "terraform not found (install from https://developer.hashicorp.com/terraform/install)"
fi

# ansible >= 2.12
if command -v ansible &>/dev/null; then
    ANSIBLE_VER=$(ansible --version | head -1 | grep -oP '[\d.]+' | head -1)
    ANSIBLE_MAJOR=$(echo "$ANSIBLE_VER" | cut -d. -f1)
    ANSIBLE_MINOR=$(echo "$ANSIBLE_VER" | cut -d. -f2)
    if [ "${ANSIBLE_MAJOR}" -gt 2 ] || { [ "${ANSIBLE_MAJOR}" -eq 2 ] && [ "${ANSIBLE_MINOR}" -ge 12 ]; }; then
        pass "ansible ${ANSIBLE_VER}"
    else
        fail "ansible ${ANSIBLE_VER} — version >= 2.12 required"
    fi
else
    fail "ansible not found (pip install ansible)"
fi

# ansible community.general collection
if command -v ansible-galaxy &>/dev/null; then
    if ansible-galaxy collection list 2>/dev/null | grep -q "community.general"; then
        CGEN_VER=$(ansible-galaxy collection list 2>/dev/null | grep "community.general" | awk '{print $2}' | head -1)
        pass "ansible community.general ${CGEN_VER}"
    else
        fail "community.general collection not installed — run: ansible-galaxy collection install community.general"
    fi
else
    warn "ansible-galaxy not found; cannot check community.general"
fi

# doctl
if command -v doctl &>/dev/null; then
    DOCTL_VER=$(doctl version 2>/dev/null | grep -oP '[\d.]+' | head -1 || echo "unknown")
    pass "doctl ${DOCTL_VER}"
else
    fail "doctl not found (brew install doctl  or  https://docs.digitalocean.com/reference/doctl/how-to/install/)"
fi

# rsync (used by deploy.sh)
if command -v rsync &>/dev/null; then
    pass "rsync"
else
    warn "rsync not found — required only for the manual deploy.sh path; not needed for Ansible deployments"
fi

# =============================================================================
# Terraform configuration
# =============================================================================
header "Terraform configuration"

TFVARS="$PROJECT_ROOT/terraform/environments/example/terraform.tfvars"
TFVARS_EXAMPLE="${TFVARS}.example"

if [ -f "$TFVARS" ]; then
    pass "terraform.tfvars exists"
    # Check for unfilled placeholder values (CAPS or obvious defaults)
    if grep -qE 'dop_v1_\.\.\.|YOUR_|<[A-Z_]+>|ab:cd:ef' "$TFVARS" 2>/dev/null; then
        fail "terraform.tfvars contains unfilled placeholder values — edit it and replace all placeholders"
    else
        pass "terraform.tfvars has no obvious placeholder values"
    fi
    # Check ssh_allowed_ips is not 0.0.0.0/0
    if grep -qE '"0\.0\.0\.0/0"' "$TFVARS" 2>/dev/null; then
        fail "ssh_allowed_ips includes 0.0.0.0/0 — restrict SSH to your IP address(es)"
    else
        pass "ssh_allowed_ips is not open to the world"
    fi
else
    if [ -f "$TFVARS_EXAMPLE" ]; then
        fail "terraform.tfvars not found — copy and configure it:
          cp $TFVARS_EXAMPLE $TFVARS"
    else
        fail "terraform.tfvars not found (and terraform.tfvars.example is missing)"
    fi
fi

# =============================================================================
# Ansible configuration
# =============================================================================
header "Ansible configuration"

ALL_VARS="$PROJECT_ROOT/ansible/group_vars/all.yml"
MANUAL_INV="$PROJECT_ROOT/ansible/inventory/manual.yml"
PROD_INV="$PROJECT_ROOT/ansible/inventory/production.yml"

if [ -f "$ALL_VARS" ]; then
    pass "ansible/group_vars/all.yml exists"
    # Check project_name has been set to something real
    if grep -qE 'project_name:\s*"your-project-name"' "$ALL_VARS" 2>/dev/null; then
        fail "project_name in group_vars/all.yml is still the default — set it to your project name"
    else
        pass "project_name appears to be configured"
    fi
    # Check vpc_cidr has been set
    if grep -qE 'vpc_cidr:\s*"10\.x\.x\.x/xx"' "$ALL_VARS" 2>/dev/null; then
        fail "vpc_cidr in group_vars/all.yml is still the placeholder — set it to your VPC CIDR (doctl vpcs list)"
    else
        pass "vpc_cidr appears to be configured"
    fi
else
    fail "ansible/group_vars/all.yml not found"
fi

if [ -f "$PROD_INV" ]; then
    pass "ansible/inventory/production.yml exists (Terraform-generated)"
    warn "Verify production.yml has been regenerated after your latest terraform apply"
elif [ -f "$MANUAL_INV" ]; then
    # Check if manual inventory still has placeholder IPs
    if grep -qE 'MANAGEMENT_NODE_PUBLIC_IP|MANAGEMENT_NODE_PRIVATE_IP|YOUR_SERVER' "$MANUAL_INV" 2>/dev/null; then
        fail "ansible/inventory/manual.yml still contains placeholder IP addresses — update them with your Terraform outputs"
    else
        pass "ansible/inventory/manual.yml appears to be configured"
    fi
else
    fail "No Ansible inventory found — run terraform apply (auto-generates production.yml) or populate manual.yml"
fi

# =============================================================================
# DigitalOcean authentication
# =============================================================================
header "DigitalOcean CLI authentication"

if command -v doctl &>/dev/null; then
    if doctl account get &>/dev/null; then
        DO_EMAIL=$(doctl account get --format Email --no-header 2>/dev/null || echo "authenticated")
        pass "doctl authenticated (${DO_EMAIL})"
    else
        fail "doctl not authenticated — run: doctl auth init"
    fi
else
    warn "doctl not found; skipping authentication check"
fi

# =============================================================================
# Summary
# =============================================================================
echo ""
echo "=================================================="
if [ "$FAILURES" -eq 0 ] && [ "$WARNINGS" -eq 0 ]; then
    echo -e "${GREEN}${BOLD}All checks passed. Ready to deploy.${NC}"
    echo ""
    echo "Next: cd terraform/environments/example && terraform init && terraform apply"
elif [ "$FAILURES" -eq 0 ]; then
    echo -e "${YELLOW}${BOLD}${WARNINGS} warning(s) — review before deploying.${NC}"
    echo ""
    echo "Next: cd terraform/environments/example && terraform init && terraform apply"
else
    echo -e "${RED}${BOLD}${FAILURES} check(s) failed — fix the above before deploying.${NC}"
    if [ "$WARNINGS" -gt 0 ]; then
        echo -e "${YELLOW}${WARNINGS} warning(s) also present.${NC}"
    fi
    exit 1
fi
echo "=================================================="
