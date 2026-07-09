# Architecture

## What it is

Heimdall is a reproducible, zero-trust observability stack: one Terraform root module provisions the DigitalOcean infrastructure, one Ansible playbook configures it, and Docker Compose runs the stack on the management node. A new user clones the repo, sets a handful of variables, and gets a working Prometheus + Grafana + Loki + Alertmanager deployment in under an hour.

The stack is intentionally single-management-node — one hub scrapes metrics and aggregates logs from all other nodes via the VPC private network. HA is a post-1.0 consideration; for most small teams one well-monitored hub is the right tradeoff.

---

## Component map

```
┌──────────────────────────────────────────────────────────────┐
│                         Your VPC                             │
│                                                              │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐      │
│  │  App Node 1 │    │  App Node 2 │    │  App Node N │      │
│  │             │    │             │    │             │      │
│  │node_exporter│    │node_exporter│    │node_exporter│      │
│  │  :9100      │    │  :9100      │    │  :9100      │      │
│  │             │    │             │    │             │      │
│  │  promtail   │    │  promtail   │    │  promtail   │      │
│  │  :9080      │    │  :9080      │    │  :9080      │      │
│  └──────┬──────┘    └──────┬──────┘    └──────┬──────┘      │
│         │                  │                  │             │
│         └──────────────────┼──────────────────┘             │
│                   VPC private network                        │
│                   (pull: node_exporter)                      │
│                   (push: promtail → loki)                    │
│                            │                                │
│                            ▼                                │
│                  ┌───────────────────┐                      │
│                  │  Management Node  │                      │
│                  │                   │                      │
│                  │  ┌─────────────┐  │                      │
│                  │  │ Prometheus  │  │◄── Tailscale ──── You│
│                  │  │ :9090       │  │    (authenticated)   │
│                  │  ├─────────────┤  │                      │
│                  │  │ Grafana     │  │                      │
│                  │  │ :3000       │  │                      │
│                  │  ├─────────────┤  │                      │
│                  │  │ Loki        │  │                      │
│                  │  │ :3100       │  │                      │
│                  │  ├─────────────┤  │                      │
│                  │  │ Alertmanager│  │                      │
│                  │  │ :9093       │  │                      │
│                  │  ├─────────────┤  │                      │
│                  │  │ node_export │  │                      │
│                  │  │ :9100       │  │                      │
│                  │  ├─────────────┤  │                      │
│                  │  │ promtail    │  │                      │
│                  │  │ :9080       │  │                      │
│                  │  └─────────────┘  │                      │
│                  └─────────┬─────────┘                      │
│                            │                                │
└────────────────────────────┼────────────────────────────────┘
                             │ (optional: long-term archival)
                             ▼
                   ┌──────────────────┐
                   │  Spaces / S3     │
                   │  (log archival)  │
                   └──────────────────┘
```

---

## Components

### Management node

A single DigitalOcean Droplet that runs the full monitoring stack via Docker Compose. It is the only node that needs management-level access — all other nodes are application nodes that export metrics and push logs to it.

Minimum recommended size: `s-2vcpu-4gb` (~$24/mo). The Docker images together use ~1.5–2 GB RAM at idle.

### Prometheus

Scrapes Node Exporter on the management node itself (`node-exporter-management` job) and on all application nodes (`node-exporter-apps` job). Targets for application nodes are populated from the Ansible inventory via the `groups['application_servers']` group — adding a node to inventory automatically adds it to Prometheus scrape targets on the next playbook run.

Metrics are retained locally for 15 days (configurable via `--storage.tsdb.retention.time`). Prometheus also scrapes its own internals, Grafana, Loki, and Alertmanager for monitoring-stack health.

Alert rules live in `prometheus/alerts.yml` and cover: instance down, high CPU (>85%), high memory (>90%), disk space low (<20%), Loki not receiving logs, Alertmanager disconnected.

### Grafana

Dashboards and datasources are provisioned at startup from `grafana/provisioning/`. The default dashboard (`host-overview.json`) shows management node status, app server up/down counts, and CPU / memory / disk / network panels for every monitored node — all driven by label selectors, with no hardcoded instance names.

Datasources: Prometheus (`http://prometheus:9090`) and Loki (`http://loki:3100`) are pre-configured.

Grafana is accessible only over Tailscale. The `GF_SERVER_ROOT_URL` is set to the Tailscale hostname for correct link generation in alert emails.

### Loki

Receives log streams pushed by Promtail agents. Configured with 14-day local retention (`retention_period: 336h`). Long-term archival to a DigitalOcean Spaces (S3-compatible) bucket is documented in the config but disabled by default — uncomment the `storage_config` block to enable.

### Alertmanager

Routes alerts fired by Prometheus. Default configuration sends to email via SMTP. Slack and Discord webhook receivers are included as commented examples in `alertmanager.yml`. Alert subject and labels are templated from `project_name` — `[YOUR-PROJECT] FIRING: InstanceDown`.

### Node Exporter

Runs on every node (management and application) and exposes host-level metrics: CPU, memory, disk, network, filesystem. Listens on `:9100`. On application nodes, UFW is configured to allow connections from the management node's VPC IP only.

### Promtail

Runs on every node as a systemd service (application nodes) or Docker container (management node). Ships system logs, syslog, auth logs, and systemd journal to Loki over the VPC private network. App-specific log paths (Apache/WordPress, Docker containers) are available as opt-in overlays in `examples/`.

---

## Data flow

### Metrics path

```
App nodes (node_exporter :9100)
        │
        │  Prometheus pull scrape (VPC private IP, every 15s)
        ▼
Management node: Prometheus ──► evaluates alert rules
        │                              │
        │                              ▼
        │                       Alertmanager ──► email / Slack / Discord
        │
        ▼
     Grafana ──► dashboards (browser over Tailscale)
```

### Logs path

```
App nodes (promtail → push)
        │
        │  HTTP push to Loki :3100 (VPC private IP)
        ▼
Management node: Loki (stores locally 14d)
        │
        ▼
     Grafana (LogQL queries over Tailscale)
        │
        ▼
  Spaces / S3 (optional long-term archival)
```

---

## Tailscale zero-trust model

No management ports are exposed on the public internet. The Cloud Firewall blocks all inbound traffic on ports 3000 (Grafana), 9090 (Prometheus), 9093 (Alertmanager), and 3100 (Loki). The only way to reach these services is via the Tailscale mesh network, which requires device authentication.

SSH (`22`) is restricted to the explicit IP list in `ssh_allowed_ips` — there is no default, and using `0.0.0.0/0` is validated against at apply time.

Node Exporter (`:9100`) and Promtail (`:9080`) on application nodes accept connections from the management node's VPC private IP only, enforced by UFW rules written by the Ansible role. These ports are never reachable from outside the VPC.

---

## Variable / parameter model

A single `project_name` variable threads through the entire stack. Setting it in `terraform.tfvars` and `ansible/inventory/group_vars/all.yml` produces:

| Resource | Derived value |
|---|---|
| Droplet name | `<project_name>-management` |
| Cloud Firewall name | `<project_name>-management-firewall` |
| Resource tags | `[management, monitoring, <project_name>]` |
| Spaces bucket | `<project_name>-logs-<region>` (or override) |
| Project directory | `/opt/<project_name>-monitoring` |
| Prometheus `project` label | `<project_name>` |
| Alertmanager subject prefix | `[<PROJECT_NAME>]` |
| Grafana folder | `<project_name> Infrastructure` |
| Grafana folder UID | `<project_name>-infra` |

A second required variable, `vpc_cidr`, controls the CIDR-based UFW rules on application nodes (Node Exporter and Promtail only accept connections from within this range).

---

## Design decisions

**Why a single management node?** Simplicity. For most small teams monitoring a handful of nodes, HA adds operational overhead that isn't justified. The management node itself is monitored for disk, memory, and service health — if it goes down, you know.

**Why Docker Compose (not Kubernetes)?** Same reason: simplicity and cost. A single Droplet running `docker compose up -d` is reproducible, easy to reason about, cheap to run, and trivial to roll back. Kubernetes is the right answer if you're already running it — but for a dedicated monitoring hub, it's overkill.

**Why Tailscale (not a VPN gateway or bastion)?** Tailscale's device-authenticated mesh means zero firewall rules to maintain for operator access. There's no bastion to patch, no VPN to configure, no shared credentials. Each operator authenticates their device once and gets access. The `.dev` TLS constraint is a bonus — browser HTTPS "just works" if you wire up a domain.

**Why Terraform modules?** The `droplet`, `firewall`, and `spaces-bucket` modules let a team add staging/dev environments without copy-paste. They're thin wrappers today and can grow independently.

**Why Ansible roles (not scripts)?** Idempotency. Running the playbook twice produces the same result. Scripts are imperative and don't survive re-runs cleanly. Ansible roles also compose — the `monitoring-stack` role can be updated and re-applied without re-running security hardening.

**Why pin image versions?** Reproducibility. Unpinned tags (`latest`) mean your next deploy might pull a breaking change. Current pins: Prometheus v2.51.0, Grafana 10.4.1, Loki/Promtail 2.9.6, Alertmanager v0.27.0, Node Exporter v1.7.0. Bumps are tracked via Dependabot.
