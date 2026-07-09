# Customization Guide

**Deploy Heimdall for your org in under an hour.**

This guide walks through everything — from prerequisites to a working Grafana dashboard — using a concrete worked example (`project_name = "acme"`).

---

## Prerequisites

Before you start, have the following ready:

| Requirement | Where to get it |
|---|---|
| DigitalOcean API token | [cloud.digitalocean.com/account/api/tokens](https://cloud.digitalocean.com/account/api/tokens) |
| Spaces access key + secret | [cloud.digitalocean.com/spaces/access_keys](https://cloud.digitalocean.com/spaces/access_keys) |
| Existing DigitalOcean VPC | Create one at cloud.digitalocean.com → Networking → VPCs |
| SSH key registered with DO | `doctl compute ssh-key list` to find the fingerprint |
| Tailscale account | [tailscale.com](https://tailscale.com/) — free tier is fine |
| Local tools | `terraform >= 1.0`, `ansible >= 2.12`, `doctl` |

---

## Step 1 — Clone and pick a project name

```bash
git clone https://github.com/brett-buskirk/heimdall.git
cd heimdall
```

Pick a short, lowercase identifier for this deployment. It becomes the prefix for every resource name: the Droplet, the Firewall, the Spaces bucket, and the monitoring directory on disk. Keep it to 2–32 characters, lowercase, no leading or trailing hyphens.

**Worked example:** `project_name = "acme"`

---

## Step 2 — Configure Terraform

```bash
cp terraform/environments/example/terraform.tfvars.example \
   terraform/environments/example/terraform.tfvars
```

Edit `terraform.tfvars` — never commit this file (it's in `.gitignore`):

```hcl
# Authentication
do_token          = "dop_v1_..."           # Your DO API token
spaces_access_id  = "..."                  # Spaces access key ID
spaces_secret_key = "..."                  # Spaces secret key

# Project
project_name = "acme"                      # Your chosen prefix

# Infrastructure
region          = "nyc3"                   # DO region slug
vpc_name        = "acme-vpc"              # Your existing VPC name
ssh_fingerprint = "ab:cd:ef:..."           # From: doctl compute ssh-key list

# Management node
management_node_size = "s-2vcpu-4gb"      # ~$24/mo — minimum recommended

# Security — REQUIRED, no default
ssh_allowed_ips = ["203.0.113.10/32"]     # Your IP(s); never use 0.0.0.0/0

# Monitoring
alert_email = "alerts@acme.com"
```

### All Terraform variables

| Variable | Required | Default | Description |
|---|---|---|---|
| `do_token` | Yes | — | DigitalOcean API token |
| `spaces_access_id` | Yes | — | Spaces access key ID |
| `spaces_secret_key` | Yes | — | Spaces secret key |
| `project_name` | Yes | — | Short deployment identifier (prefixes all resources) |
| `vpc_name` | Yes | — | Name of your existing DigitalOcean VPC |
| `ssh_fingerprint` | Yes | — | SSH key fingerprint registered with DigitalOcean |
| `ssh_allowed_ips` | Yes | — | List of IPs/CIDRs allowed to SSH to the management node |
| `region` | No | `"nyc3"` | DigitalOcean region slug |
| `management_node_size` | No | `"s-2vcpu-4gb"` | Droplet size for the management node |
| `log_bucket_name` | No | `""` | Spaces bucket name; auto-derived as `<project_name>-logs-<region>` if empty |
| `enable_public_grafana` | No | `false` | Expose Grafana publicly (not recommended — use Tailscale) |
| `grafana_domain` | No | `""` | Domain for Grafana; only used when `enable_public_grafana = true` |
| `alert_email` | No | `""` | Email address for alert notifications |

---

## Step 3 — Provision infrastructure

```bash
cd terraform/environments/example
terraform init
terraform plan      # review what will be created
terraform apply
```

Note the outputs:

```
management_node_ip         = "123.45.67.89"
management_node_private_ip = "10.x.x.x"
management_node_name       = "acme-management"
log_bucket_name            = "acme-logs-nyc3"
```

You'll need `management_node_ip` and `management_node_private_ip` for the next steps.

---

## Step 4 — Configure Ansible

### group_vars

Edit `ansible/inventory/group_vars/all.yml`:

```yaml
# REQUIRED — must match terraform.tfvars
project_name: "acme"

# REQUIRED — your VPC CIDR block
# Find it: doctl vpcs list
vpc_cidr: "10.110.0.0/20"

# Optional — update to match your setup
deploy_environment: production
timezone: America/New_York
alert_email: "alerts@acme.com"
grafana_root_url: "http://acme-management"  # Tailscale hostname or IP
```

### Inventory

Edit `ansible/inventory/manual.yml`:

```yaml
all:
  children:
    management:
      hosts:
        acme-management:
          ansible_host: 123.45.67.89        # management_node_ip from terraform output
          private_ip: 10.110.0.5            # management_node_private_ip
          ansible_user: root
          ansible_python_interpreter: /usr/bin/python3

    application_servers:
      hosts:
        app-server-1:
          ansible_host: 123.45.67.90        # your app server public IP
          private_ip: 10.110.0.6            # VPC private IP
          ansible_user: root
          ansible_python_interpreter: /usr/bin/python3

  vars:
    prometheus_server: 10.110.0.5           # management node VPC IP
    loki_server: 10.110.0.5
```

### All Ansible variables

| Variable | Required | Default | Description |
|---|---|---|---|
| `project_name` | Yes | `"your-project-name"` | Matches `terraform.tfvars`; prefixes the project directory |
| `vpc_cidr` | Yes | `"10.x.x.x/xx"` | VPC CIDR block; used in UFW rules on all nodes |
| `deploy_environment` | No | `"production"` | Label applied to Prometheus external labels |
| `timezone` | No | `"America/New_York"` | System timezone for all nodes |
| `grafana_admin_user` | No | `"admin"` | Grafana admin username |
| `grafana_root_url` | No | `"http://localhost:3000"` | Grafana public URL (set to Tailscale hostname) |
| `alert_email` | No | `"alerts@yourdomain.com"` | Alertmanager alert destination |
| `loki_server` | No | `"10.x.x.x"` | Management node VPC IP — set in inventory vars |
| `prometheus_server` | No | `"10.x.x.x"` | Management node VPC IP — set in inventory vars |

---

## Step 5 — Configure the monitoring stack environment

```bash
cp docker/monitoring/.env.example docker/monitoring/.env
```

Edit `.env`:

```bash
# Required
GRAFANA_ADMIN_PASSWORD=a-strong-password-here

# Optional: email alerts
SMTP_ENABLED=true
SMTP_HOST=smtp.mailgun.org:587
SMTP_USER=your-smtp-user
SMTP_PASSWORD=your-smtp-password
SMTP_FROM=alerts@acme.com
```

Copy the `.env` file to the management node before running the playbook, or let the playbook copy it (it references the `project_dir`):

```bash
scp docker/monitoring/.env root@123.45.67.89:/opt/acme-monitoring/.env
```

---

## Step 6 — Deploy the monitoring stack

Install Ansible Galaxy dependencies first:

```bash
ansible-galaxy collection install community.general
```

Run the management node playbook:

```bash
ansible-playbook -i ansible/inventory/manual.yml \
  ansible/playbooks/management-node.yml
```

This installs Docker, deploys the full stack, starts all containers, and waits for Grafana to become healthy. It's idempotent — re-running it is safe.

To deploy agents to your application nodes:

```bash
ansible-playbook -i ansible/inventory/manual.yml \
  ansible/playbooks/deploy-agents.yml
```

This installs Node Exporter and Promtail as systemd services on every host in the `application_servers` group, and opens the UFW rules needed for the management node to scrape them.

---

## Step 7 — Set up Tailscale

On the management node:

```bash
scp scripts/setup-tailscale.sh root@123.45.67.89:/tmp/
ssh root@123.45.67.89 'bash /tmp/setup-tailscale.sh'

# Authenticate this node to your Tailscale network
ssh root@123.45.67.89 'sudo tailscale up'
# Follow the printed URL to authenticate
```

After authentication, the node gets a Tailscale hostname (e.g. `acme-management`) and a stable Tailscale IP. Use either to access the stack from any authorized device.

---

## Step 8 — Verify

From any device on your Tailscale network:

```
http://acme-management:3000       → Grafana (log in with admin / your password)
http://acme-management:9090       → Prometheus (check Targets — all should be UP)
http://acme-management:9093       → Alertmanager
```

In Grafana, navigate to **Infrastructure → Infrastructure Overview** to see all monitored nodes.

---

## Adding monitored nodes

1. Add the node to `application_servers` in your inventory file
2. Re-run the agents playbook: `ansible-playbook -i inventory/manual.yml playbooks/deploy-agents.yml --limit <new-node>`
3. Prometheus picks up the new target automatically (it reads from `groups['application_servers']` in the Ansible inventory)

No Prometheus config edits needed.

---

## App-specific extensions

The default stack monitors host health (CPU, memory, disk, network) generically. For app-specific monitoring (WordPress/Apache logs, Foundry VTT Docker logs, custom alert rules) see `examples/wordpress-foundry/` for a worked overlay example. The README in that directory explains how to apply the overlay.

---

## Using Terraform-generated inventory

After `terraform apply`, Terraform writes a populated inventory file to `ansible/inventory/production.yml` (from the `local_file.ansible_inventory` resource). Use this instead of editing `manual.yml` by hand:

```bash
# After terraform apply:
ansible-playbook -i ansible/inventory/production.yml \
  ansible/playbooks/management-node.yml
```

The generated inventory includes all VPC nodes discovered via the `digitalocean_droplets` data source.

---

## Security

**`ssh_allowed_ips` is required with no default.** This is intentional — deploying with `0.0.0.0/0` is a common security mistake. The Terraform validation will reject an empty list.

**Never commit `terraform.tfvars` or `.env`.** Both are in `.gitignore`. Only ever commit `*.example` files. Verify with `git status` before pushing.

**Grafana password**: set `GRAFANA_ADMIN_PASSWORD` in `.env` before running the playbook. The playbook will fail with a clear error if it's not set.

---

## Pre-deploy checklist

Run the preflight script before your first `terraform apply` to catch missing tools or unfilled placeholders:

```bash
./scripts/preflight.sh
```

It checks tool versions, verifies that `terraform.tfvars` and `ansible/inventory/group_vars/all.yml` have been populated, confirms that `ssh_allowed_ips` is not open to the world, and validates that the DigitalOcean CLI is authenticated. Fix any failures it reports before proceeding.

---

## Remote state backend (recommended for teams)

By default, Terraform stores state locally in `terraform/environments/example/terraform.tfstate`. This is fine for solo deployments but creates a problem for teams: two people can't safely run `terraform apply` against the same state at the same time, and local state is lost if the workstation is wiped.

DigitalOcean Spaces is S3-compatible and works as a remote state backend with locking via DynamoDB (or without locking, which is usually acceptable for small teams).

### Set up a state bucket

Create a Spaces bucket for state storage. Name it something like `<project_name>-terraform-state`. It should be in the same region as your other resources:

```bash
doctl spaces bucket create <project_name>-terraform-state --region nyc3
```

Keep the bucket **private** and do not store it alongside application logs. It holds your Terraform state, which includes resource IDs and (in some providers) sensitive outputs.

### Configure the backend

The backend block is already in `terraform/environments/example/main.tf` as a comment. Uncomment and fill it in:

```hcl
backend "s3" {
  endpoint = "nyc3.digitaloceanspaces.com"
  bucket   = "acme-terraform-state"         # your state bucket name
  key      = "terraform/acme/terraform.tfstate"

  # Required by the S3 backend; ignored by DO Spaces
  region                      = "us-east-1"
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_region_validation      = true
  force_path_style            = true

  # Spaces credentials — use the same key pair as spaces_access_id/spaces_secret_key
  # Pass via environment variables rather than hardcoding:
  #   export AWS_ACCESS_KEY_ID=<spaces_access_key_id>
  #   export AWS_SECRET_ACCESS_KEY=<spaces_secret_key>
}
```

Pass Spaces credentials as environment variables (the S3 backend reads `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY`):

```bash
export AWS_ACCESS_KEY_ID=<your_spaces_access_key_id>
export AWS_SECRET_ACCESS_KEY=<your_spaces_secret_key>
```

### Migrate existing local state

If you have existing local state, migrate it to the remote backend with `terraform init -migrate-state`. Terraform will prompt you to confirm the migration:

```bash
cd terraform/environments/example
terraform init -migrate-state
```

After migration, the local `terraform.tfstate` file can be deleted (but keep `.terraform/` — it caches provider plugins).

### State locking

The S3 backend supports optional DynamoDB-based state locking, but DigitalOcean does not offer a managed DynamoDB equivalent. For most small teams the risk of a concurrent apply race is low. If you need locking, consider self-hosting a locking proxy (e.g. `terraform-backend-http`) or using a workspace-per-environment strategy.

---

## Teardown

### Stop the stack first (recommended)

Before destroying infrastructure, stop the monitoring stack cleanly to avoid orphaned processes and to give Tailscale time to deregister the node:

```bash
ssh root@<management_node_ip> "cd /opt/<project_name>-monitoring && docker compose down"
```

### Remove from Tailscale

If the management node is enrolled in Tailscale, remove it from your tailnet before destroying the Droplet, so the entry doesn't linger in the admin console:

```bash
# On the management node:
ssh root@<management_node_ip> "tailscale logout"
```

Or remove it via the Tailscale admin console at tailscale.com/admin/machines.

### Destroy infrastructure

```bash
cd terraform/environments/example

# Option A — destroy compute only, keep the log bucket and its data
terraform destroy \
  -target=module.management_node \
  -target=module.management_firewall

# Option B — full teardown including the Spaces bucket
# Note: the bucket must be empty first (Terraform will error if it has objects)
terraform destroy
```

If the Spaces bucket contains objects and `terraform destroy` fails, empty it first:

```bash
doctl spaces object remove <bucket-name> --recursive
# Then re-run terraform destroy
```

### Clean up local files

```bash
# Remove the auto-generated Ansible inventory
rm -f ansible/inventory/production.yml

# If using local state, remove it too
rm -f terraform/environments/example/terraform.tfstate
rm -f terraform/environments/example/terraform.tfstate.backup
```
