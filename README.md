# Heimdall

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

**Drop-in observability stack for DigitalOcean — Prometheus, Grafana, Loki, and Alertmanager on a Tailscale-secured VPC, provisioned with Terraform + Ansible.**

One `terraform apply` and one `ansible-playbook` run gives any team a complete metrics, logs, and alerting hub — with zero management ports exposed to the public internet.

> Not an engineer? Read the [plain-language overview](docs/ABOUT.md) — what Heimdall is and why it exists, no jargon.

---

## What it deploys

**Infrastructure (Terraform):**
- DigitalOcean VPC with private networking
- Management droplet — the monitoring hub
- Cloud Firewall with a Tailscale-first security model (no public management ports)
- DigitalOcean Spaces bucket for long-term log archival

**Observability stack (Ansible + Docker Compose):**

| Component | Role | Port |
|---|---|---|
| Prometheus | Metrics collection, evaluation, and alerting rules | 9090 |
| Grafana | Dashboards and visualization | 3000 |
| Loki | Log aggregation | 3100 |
| Alertmanager | Alert routing — email, Slack, Discord | 9093 |
| Node Exporter | Host-level metrics on every monitored node | 9100 |
| Promtail | Log shipping from every monitored node | 9080 |

**Access model:** Grafana, Prometheus, and Alertmanager are bound to private interfaces only. All access is via [Tailscale](https://tailscale.com/) — authenticated mesh VPN, no public ports.

---

## Architecture

```
┌──────────────────────────────────────────────────────────────┐
│                         Your VPC                             │
│                                                              │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐      │
│  │  App Node 1 │    │  App Node 2 │    │  App Node N │      │
│  │             │    │             │    │             │      │
│  │node_exporter│    │node_exporter│    │node_exporter│      │
│  │  promtail   │    │  promtail   │    │  promtail   │      │
│  └──────┬──────┘    └──────┬──────┘    └──────┬──────┘      │
│         │                  │                  │             │
│         └──────────────────┼──────────────────┘             │
│                     VPC private network                      │
│                            │                                │
│                            ▼                                │
│                  ┌───────────────────┐                      │
│                  │  Management Node  │                      │
│                  │  ─────────────── ◄──── Tailscale ──── You│
│                  │  • Prometheus     │     (zero-trust)     │
│                  │  • Grafana        │                      │
│                  │  • Loki           │                      │
│                  │  • Alertmanager   │                      │
│                  └─────────┬─────────┘                      │
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

See [ARCHITECTURE.md](ARCHITECTURE.md) for a full component map, data-flow walkthrough, and the reasoning behind the design.

---

## Project structure

```
heimdall/
├── terraform/
│   ├── environments/example/      # Root module — clone this to deploy
│   └── modules/
│       ├── droplet/               # Reusable droplet definition
│       ├── firewall/              # Cloud Firewall rules
│       └── spaces-bucket/         # Object storage for log archival
├── ansible/
│   ├── playbooks/
│   │   ├── management-node.yml    # Full management node setup
│   │   └── deploy-agents.yml      # Node Exporter + Promtail on app nodes
│   ├── roles/
│   │   ├── common/                # Base packages, timezone, system config
│   │   ├── security/              # UFW, fail2ban, SSH hardening
│   │   ├── docker/                # Docker Engine + Compose plugin
│   │   ├── monitoring-stack/      # Full observability stack
│   │   ├── node-exporter/         # Metrics agent
│   │   └── promtail-agent/        # Log shipping agent
│   ├── group_vars/all.yml         # Deployment variables
│   └── inventory/                 # Inventory files (generated, gitignored)
├── docker/monitoring/             # Static configs (mirrors Ansible output)
│   ├── docker-compose.yml
│   ├── prometheus/
│   ├── grafana/
│   ├── loki/
│   ├── alertmanager/
│   └── .env.example
├── examples/
│   └── wordpress-foundry/         # App-specific overlay example
├── docs/
│   ├── ABOUT.md                   # Plain-language overview
│   └── ARCHITECTURE.md            # → symlink or see ARCHITECTURE.md at root
└── scripts/
    ├── deploy.sh                  # Manual sync + restart (non-Ansible path)
    └── setup-tailscale.sh         # Tailscale install helper
```

---

## Prerequisites

- DigitalOcean account with an API token and Spaces access keys
- An existing DigitalOcean VPC (Heimdall deploys a management node into it)
- SSH key registered with DigitalOcean (`doctl compute ssh-key list`)
- Tailscale account (free tier is sufficient)
- Local tools: `terraform >= 1.0`, `ansible >= 2.12`, `doctl`

---

## Quick start

The detailed, step-by-step deployment guide — with a worked example — is in **[CUSTOMIZATION.md](CUSTOMIZATION.md)**. The five-step summary:

```bash
# 0. Clone, configure, and run the preflight check
git clone https://github.com/brett-buskirk/heimdall.git
cd heimdall
cp terraform/environments/example/terraform.tfvars.example \
   terraform/environments/example/terraform.tfvars
# Edit terraform.tfvars: do_token, project_name, vpc_name, ssh_fingerprint, ssh_allowed_ips
# Edit ansible/group_vars/all.yml: project_name, vpc_cidr
./scripts/preflight.sh   # verify tools and config before applying

# 1. Provision infrastructure
cd terraform/environments/example && terraform init && terraform apply

# 2. Deploy the monitoring stack
ansible-playbook -i ansible/inventory/production.yml ansible/playbooks/management-node.yml

# 3. Deploy agents to app nodes
ansible-playbook -i ansible/inventory/production.yml ansible/playbooks/deploy-agents.yml

# 4. Install Tailscale and connect
scp scripts/setup-tailscale.sh root@<management_ip>:/tmp/
ssh root@<management_ip> 'bash /tmp/setup-tailscale.sh && sudo tailscale up'
```

After Tailscale is up, reach the stack at `http://<tailscale-hostname>:3000` (Grafana).

---

## Security model

All management ports (Grafana on 3000, Prometheus on 9090, Alertmanager on 9093) are bound to private interfaces and blocked at the Cloud Firewall. The only access path is Tailscale — authenticated, encrypted, and auditable. There are no public-facing management endpoints.

SSH is restricted to the IPs in `ssh_allowed_ips` (required, no default — see [CUSTOMIZATION.md](CUSTOMIZATION.md#security)). Node Exporter and Promtail on application nodes only accept connections from the management node's VPC private IP; they never talk cross-node or to the public internet.

See [SECURITY.md](SECURITY.md) for the supported-version policy and how to report vulnerabilities privately.

---

## Teardown

Stop the stack cleanly before destroying infrastructure:

```bash
# 1. Stop the monitoring stack and deregister from Tailscale
ssh root@<management_node_ip> \
  "cd /opt/<project_name>-monitoring && docker compose down && tailscale logout"

# 2a. Destroy compute only — keep log bucket and its data
cd terraform/environments/example
terraform destroy \
  -target=module.management_node \
  -target=module.management_firewall

# 2b. Full teardown including the Spaces bucket
#     (bucket must be empty first — see CUSTOMIZATION.md if it has objects)
terraform destroy
```

See [CUSTOMIZATION.md](CUSTOMIZATION.md#teardown) for the complete teardown runbook, including how to empty the Spaces bucket and clean up local state files.

---

## Maintenance

```bash
# Update stack images on the management node
ssh root@<management_node_ip>
cd /opt/<project_name>-monitoring
docker compose pull && docker compose up -d

# Tail logs for a specific service
docker compose logs -f grafana

# Add a new monitored node
# 1. Add it to ansible/inventory/production.yml
# 2. ansible-playbook -i inventory/production.yml playbooks/deploy-agents.yml --limit <new-node>
# Prometheus auto-discovers it from the Ansible inventory on the next playbook run
```

---

## Documentation

| Document | Purpose |
|---|---|
| [CUSTOMIZATION.md](CUSTOMIZATION.md) | Step-by-step deployment guide, remote state, teardown runbook |
| [ARCHITECTURE.md](ARCHITECTURE.md) | Component map, data-flow, design decisions |
| [docs/ABOUT.md](docs/ABOUT.md) | Plain-language overview — no jargon |
| [CONTRIBUTING.md](CONTRIBUTING.md) | How to contribute, validation gates, conventions |
| [SECURITY.md](SECURITY.md) | Vulnerability reporting and security posture |
| [CHANGELOG.md](CHANGELOG.md) | Release history |
| [ROADMAP.md](ROADMAP.md) | Planned phases and post-1.0 ideas |
| [scripts/preflight.sh](scripts/preflight.sh) | Pre-deploy environment check |

---

Built by [Brett Buskirk LLC](https://brett-buskirk.dev) · MIT License
