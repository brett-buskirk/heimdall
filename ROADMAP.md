# Roadmap

## Phase 0 — Scaffold conventions ✅ *(June 2026)*

- [x] Repo renamed to `heimdall`
- [x] `LICENSE` (MIT), `CHANGELOG`, `ROADMAP`, `CONTRIBUTING`, `SECURITY`, `CLAUDE.md`
- [x] `.github/` — issue templates, PR template, Dependabot
- [x] GitHub labels, milestones, project board
- [x] Repo metadata and topics set

## v0.1.0 — Generalize Terraform ✅

- [x] Introduce `project_name` variable; thread through all resource names, tags, outputs
- [x] Remove every org-specific default (`rcj-vpc-nyc3`, `rcj-logs-nyc3`, `rcj-management`)
- [x] Rename `environments/production/` → `environments/example/`
- [x] Safe security defaults — `ssh_allowed_ips` required, documented
- [x] `terraform fmt -check` and `terraform validate` clean

## v0.2.0 — Generalize Ansible ✅

- [x] Parameterize `group_vars/all.yml` — `project_name`, `vpc_cidr`, `project_dir`
- [x] Degenericize all roles and Jinja2 templates — no hardcoded `rcj-*` strings
- [x] Generic inventory example (replaces `inventory/manual.yml`)
- [x] `ansible-lint` clean

## v0.3.0 — App-agnostic monitoring ✅

- [x] Replace hardcoded `rc-journey-wp` / `foundry-vtt` targets with inventory-driven scrape targets
- [x] Generic host dashboard (Grafana) — node health for any node
- [x] Generic node-health alert rules — `InstanceDown`, `HighCPU`, `HighMemory`, `DiskFull`
- [x] Generic Promtail config — journald + syslog by default; app overlays opt-in
- [x] Move WordPress / Foundry specifics to `examples/wordpress-foundry/`
- [x] Org-specific grep returns zero hits outside `examples/`

## v0.4.0 — Docs & examples ✅

- [x] Rewrite `README.md` — generic pitch, architecture diagram, quickstart, security model
- [x] `ARCHITECTURE.md` — component map, data-flow, Tailscale zero-trust model, variable model
- [x] `CUSTOMIZATION.md` — step-by-step "deploy for your org in 15 minutes" with worked example
- [x] `docs/ABOUT.md` — plain-language overview (no jargon)
- [x] All variables documented with descriptions

## v0.5.0 — CI & validation

- [ ] `.github/workflows/ci.yml` — `terraform fmt`, `terraform validate`, `tflint`, `ansible-lint`, `yamllint`, `shellcheck`, `promtool check rules`, `promtool test rules`, `tfsec`
- [ ] `tests/prometheus/alerts_test.yml` — unit tests for node-health and monitoring-stack alert rules
- [x] Dependabot wired for GitHub Actions and Terraform *(done in Phase 0)*
- [ ] All validation gates required before merge

## v1.0.0 — Template release

- [ ] `scripts/preflight.sh` — pre-deploy environment check
- [ ] Remote state backend guide (DigitalOcean Spaces / S3)
- [ ] Teardown runbook polished
- [ ] Architecture diagram updated with generic labels
- [ ] Tagged `v1.0.0` with release notes

## Post-1.0 ideas

- [ ] Terraform Registry publish
- [ ] Second cloud provider (AWS, Hetzner)
- [ ] HA / multi-node management setup
- [ ] Remote state backend as Terraform-managed Spaces bucket (IaC-all-the-way-down)
- [ ] Ansible Molecule for role-level integration testing
