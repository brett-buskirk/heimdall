# rcj-infra — Terraform + Ansible Observability Stack

> **Status:** This was a real production deployment, now decommissioned. The infrastructure is torn down, but the codebase is maintained here as a reference implementation. Everything in it ran in production.

A complete Infrastructure-as-Code project that provisions a DigitalOcean VPC and deploys a full observability stack — metrics, logs, and alerting — across multiple nodes. Built to be reproducible, nomad-friendly, and zero-trust by default.

## What This Deploys

**Infrastructure (Terraform):**
- DigitalOcean VPC with private networking
- Management droplet (the monitoring hub)
- Firewall rules following a Tailscale-first security model — no management ports exposed to the public internet
- DigitalOcean Spaces bucket for long-term log archival

**Observability Stack (Ansible + Docker Compose):**

| Component | Role | Port |
|-----------|------|------|
| Prometheus | Metrics collection & alerting rules | 9090 |
| Grafana | Dashboards & visualization | 3000 |
| Loki | Log aggregation | 3100 |
| Promtail | Log shipping from all nodes | 9080 |
| Alertmanager | Alert routing (email / Slack) | 9093 |
| Node Exporter | Host-level metrics on every node | 9100 |

**Access model:** Grafana, Prometheus, and Alertmanager are bound to private interfaces only. Access is via [Tailscale](https://tailscale.com/) — authenticated mesh VPN, no ports punched through the firewall.

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                        Your VPC                             │
│                                                             │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐   │
│  │  App Node 1  │    │  App Node 2  │    │  App Node N  │   │
│  │              │    │              │    │              │   │
│  │ node_exporter│    │ node_exporter│    │ node_exporter│   │
│  │   promtail   │    │   promtail   │    │   promtail   │   │
│  └──────┬───────┘    └──────┬───────┘    └──────┬───────┘   │
│         │                   │                   │           │
│         └───────────────────┼───────────────────┘           │
│                      VPC private network                    │
│                             │                               │
│                             ▼                               │
│                   ┌──────────────────┐                      │
│                   │  Management Node │                      │
│                   │  ─────────────── │                      │
│                   │  • Prometheus    │◄──── Tailscale ────► You
│                   │  • Grafana       │     (zero-trust)     │
│                   │  • Loki          │                      │
│                   │  • Alertmanager  │                      │
│                   └────────┬─────────┘                      │
│                            │                                │
└────────────────────────────┼────────────────────────────────┘
                             │
                             ▼
                   ┌──────────────────┐
                   │  Object Storage  │
                   │  (Spaces / S3)   │
                   │  Long-term logs  │
                   └──────────────────┘
```

## Project Structure

```
rcj-infra/
├── terraform/
│   ├── environments/production/   # Root module — VPC, firewall, compute
│   └── modules/
│       ├── droplet/               # Reusable droplet module
│       ├── firewall/              # Firewall rules
│       └── spaces-bucket/         # Object storage for log archival
├── ansible/
│   ├── playbooks/
│   │   ├── management-node.yml    # Full management node setup
│   │   └── deploy-agents.yml      # Node Exporter + Promtail on app nodes
│   ├── roles/
│   │   ├── common/                # Base packages, timezone, users
│   │   ├── security/              # UFW, fail2ban, SSH hardening
│   │   ├── docker/                # Docker Engine + Compose
│   │   ├── monitoring-stack/      # Full observability stack
│   │   ├── node-exporter/         # Metrics agent
│   │   └── promtail-agent/        # Log shipping agent
│   ├── group_vars/all.yml         # Global variables
│   └── inventory/                 # Inventory (generated, gitignored)
├── docker/monitoring/             # Docker Compose stack + all configs
│   ├── docker-compose.yml
│   ├── prometheus/                # Scrape config + alert rules
│   ├── grafana/                   # Dashboard provisioning
│   ├── loki/                      # Log retention config
│   ├── alertmanager/              # Alert routing config
│   └── .env.example               # Environment variable template
└── scripts/
    ├── deploy.sh                  # Sync configs + restart stack
    └── setup-tailscale.sh         # Tailscale install helper
```

## Prerequisites

- DigitalOcean account + API token
- Spaces access keys (for log archival)
- SSH key registered in DigitalOcean
- Tailscale account (free tier is fine)
- Local tools: `terraform >= 1.0`, `ansible >= 2.12`, `doctl`

## Quick Start

### 1. Clone and configure

```bash
git clone https://github.com/brett-buskirk/rcj-infra.git
cd rcj-infra

# Terraform variables
cp terraform/environments/production/terraform.tfvars.example \
   terraform/environments/production/terraform.tfvars
# Edit terraform.tfvars: do_token, ssh_fingerprint, spaces keys, etc.

# Monitoring stack environment
cp docker/monitoring/.env.example docker/monitoring/.env
# Edit .env: GRAFANA_ADMIN_PASSWORD (required), SMTP settings if using email alerts
```

### 2. Provision infrastructure

```bash
cd terraform/environments/production
terraform init
terraform plan
terraform apply
```

Note the `management_node_ip` from the output — you'll need it for the next step.

### 3. Deploy the stack

```bash
# Install Ansible dependencies
ansible-galaxy collection install community.docker

# Update ansible/group_vars/all.yml with your management node VPC IP
# Update ansible/inventory/production.yml with your node IPs

# Deploy everything to the management node
ansible-playbook -i ansible/inventory/production.yml \
  ansible/playbooks/management-node.yml

# Deploy agents to application nodes
ansible-playbook -i ansible/inventory/production.yml \
  ansible/playbooks/deploy-agents.yml
```

### 4. Set up Tailscale access

```bash
# Copy the script to your management node and run it
scp scripts/setup-tailscale.sh root@<management_ip>:/tmp/
ssh root@<management_ip> 'bash /tmp/setup-tailscale.sh && sudo tailscale up'

# After authenticating, access the stack via Tailscale hostname:
#   http://<tailscale-hostname>:3000   → Grafana
#   http://<tailscale-hostname>:9090   → Prometheus
#   http://<tailscale-hostname>:9093   → Alertmanager
```

### 5. Add application nodes

Edit `docker/monitoring/prometheus/prometheus.yml` to add your node VPC IPs under `node-exporter-apps`, then restart Prometheus:

```bash
cd /opt/monitoring && docker compose restart prometheus
```

## Alerting

Pre-configured alert rules cover:
- **Instance down** — any monitored host unreachable
- **High CPU** (>85% for 5 min)
- **High memory** (>90% for 5 min)
- **Low disk** (<20% remaining)

Configure alert delivery in `.env`:

```bash
SMTP_ENABLED=true
SMTP_HOST=smtp.mailgun.org:587
SMTP_USER=your_user
SMTP_PASSWORD=your_password
SMTP_FROM=alerts@yourdomain.com
```

Slack and Discord webhook receivers are included in `alertmanager.yml` as commented examples.

## Security Model

Firewall rules block all inbound traffic on management ports (3000, 9090, 9093) from the public internet. The only access path is Tailscale — authenticated, encrypted, and auditable. SSH is restricted to specific IPs in `terraform.tfvars` (`ssh_allowed_ips`).

Node Exporter and Promtail on application nodes only accept connections from the management node's VPC IP — no cross-node exposure.

## Teardown

```bash
cd terraform/environments/production

# Destroy compute only (preserve log bucket)
terraform destroy \
  -target=module.management_node \
  -target=module.management_firewall

# Full destroy
terraform destroy
```

## Maintenance

```bash
# Update stack images on the management node
cd /opt/monitoring
docker compose pull && docker compose up -d

# View logs
docker compose logs -f grafana

# Add a new monitored node
# 1. Add to ansible/inventory/production.yml
# 2. ansible-playbook -i inventory/production.yml playbooks/deploy-agents.yml --limit new-node
# 3. Add the VPC IP to prometheus/prometheus.yml and restart Prometheus
```

---

Built by [Brett Buskirk](https://brett-buskirk.dev) · [brett-buskirk.dev](https://brett-buskirk.dev)
