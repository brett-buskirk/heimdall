# 🏔️ RCJ Infrastructure

Infrastructure-as-Code for the **rcj-vpc-nyc3** management and observability platform.

This project deploys a complete monitoring stack for your DigitalOcean VPC, following the **Technodruidism** philosophy: robust, automated technology that travels with you.

## 🎯 What This Deploys

| Component | Purpose | Port |
|-----------|---------|------|
| **Prometheus** | Metrics collection & alerting | 9090 |
| **Grafana** | Visualization & dashboards | 3000 |
| **Loki** | Log aggregation | 3100 |
| **Alertmanager** | Alert routing (email/Slack) | 9093 |
| **Node Exporter** | Host metrics | 9100 |
| **Promtail** | Log shipping | 9080 |

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     rcj-vpc-nyc3                            │
│                                                             │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐  │
│  │ rc-journey-wp│    │ foundry-vtt  │    │   Future     │  │
│  │  (WordPress) │    │  (Game Srv)  │    │   Clients    │  │
│  │              │    │              │    │              │  │
│  │ node_exporter│    │ node_exporter│    │ node_exporter│  │
│  │   promtail   │    │   promtail   │    │   promtail   │  │
│  └──────┬───────┘    └──────┬───────┘    └──────┬───────┘  │
│         │                   │                   │          │
│         └───────────────────┼───────────────────┘          │
│                   (VPC Internal)                           │
│                             │                              │
│                             ▼                              │
│                   ┌──────────────────┐                     │
│                   │  rcj-management  │                     │
│                   │  ──────────────  │                     │
│                   │  • Prometheus    │◄──── Tailscale ────►│ You
│                   │  • Grafana       │     (secure access) │
│                   │  • Loki          │                     │
│                   │  • Alertmanager  │                     │
│                   └────────┬─────────┘                     │
│                            │                               │
└────────────────────────────┼───────────────────────────────┘
                             │
                             ▼
                   ┌──────────────────┐
                   │  DO Spaces       │
                   │  rcj-logs-nyc3   │
                   │  (Log Archive)   │
                   └──────────────────┘
```

## 🚀 Quick Start

### Prerequisites

- DigitalOcean account with API token
- Existing VPC (`rcj-vpc-nyc3`)
- SSH key registered with DigitalOcean
- Terraform >= 1.0.0
- Ansible >= 2.12
- (Recommended) Tailscale account for secure access

### 1. Clone and Configure

```bash
# Clone the repository
git clone https://github.com/yourusername/rcj-infra.git
cd rcj-infra

# Copy and edit Terraform variables
cp terraform/environments/production/terraform.tfvars.example \
   terraform/environments/production/terraform.tfvars

# Edit with your values:
# - do_token
# - spaces_access_id / spaces_secret_key
# - ssh_fingerprint
```

### 2. Deploy Infrastructure

```bash
cd terraform/environments/production

# Initialize Terraform
terraform init

# Review the plan
terraform plan

# Deploy
terraform apply
```

### 3. Configure Monitoring Stack

```bash
# Copy and edit environment file
cp docker/monitoring/.env.example docker/monitoring/.env

# Edit .env with:
# - GRAFANA_ADMIN_PASSWORD (strong password!)
# - SMTP settings (if using email alerts)
```

### 4. Deploy with Ansible

```bash
# Install Ansible requirements
ansible-galaxy collection install community.docker

# Deploy management node
ansible-playbook -i ansible/inventory/production.yml \
  ansible/playbooks/management-node.yml

# Deploy agents to application servers
ansible-playbook -i ansible/inventory/production.yml \
  ansible/playbooks/deploy-agents.yml
```

### 5. Set Up Secure Access (Tailscale)

```bash
# SSH to management node
ssh root@<management_ip>

# Install Tailscale
curl -fsSL https://tailscale.com/install.sh | sh
sudo tailscale up

# Access Grafana via Tailscale hostname
```

## 📊 Accessing Your Stack

| Without Tailscale | With Tailscale |
|-------------------|----------------|
| `http://<public_ip>:3000` | `http://rcj-management:3000` |
| Requires firewall changes | Zero-trust, no ports exposed |
| Less secure | ✅ Recommended |

## 🔔 Alerting

Alerts are configured for:

- **Instance Down** - Any monitored host unreachable
- **High CPU** (>85%) - Warning after 5 minutes
- **High Memory** (>90%) - Warning after 5 minutes
- **Disk Space Low** (<20%) - Warning
- **Foundry VTT Down** - Critical alert immediately
- **WordPress Down** - Critical alert after 2 minutes

Configure your email in `docker/monitoring/.env`:
```bash
SMTP_ENABLED=true
SMTP_HOST=smtp.mailgun.org:587
SMTP_USER=your_user
SMTP_PASSWORD=your_password
```

## 📁 Project Structure

```
rcj-infra/
├── terraform/
│   ├── environments/production/   # Production configuration
│   └── modules/                   # Reusable TF modules
├── ansible/
│   ├── playbooks/                 # Deployment playbooks
│   ├── roles/                     # Ansible roles
│   └── inventory/                 # Host inventory
├── docker/
│   └── monitoring/                # Docker Compose stack
└── scripts/                       # Helper scripts
```

## 🛠️ Maintenance

### Updating the Stack

```bash
cd /opt/rcj-monitoring
docker compose pull
docker compose up -d
```

### Viewing Logs

```bash
# All services
docker compose logs -f

# Specific service
docker compose logs -f grafana
```

### Adding New Servers

1. Add to Ansible inventory
2. Run agent deployment:
   ```bash
   ansible-playbook -i inventory/production.yml \
     playbooks/deploy-agents.yml --limit new-server
   ```
3. Update `prometheus/prometheus.yml` with new target
4. Restart Prometheus: `docker compose restart prometheus`

## 🗑️ Teardown

```bash
cd terraform/environments/production

# Keep log bucket, destroy compute
terraform destroy \
  -target=module.management_node \
  -target=module.management_firewall

# Full destroy (including logs!)
terraform destroy
```

## 🌿 Philosophy

Built for the **Work & Wander** lifestyle—infrastructure that's reproducible, portable, and resilient. Tear it down in Indiana, rebuild it in Oregon, and your dashboards are waiting.

---

*Part of the RCJ Technodruidism stack*
