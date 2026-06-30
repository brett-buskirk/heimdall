# Heimdall — Claude Code Build Brief
### A generic, drop-in observability + IaC template for DigitalOcean

> **Working name "Heimdall"** — the Norse watchman who guards the Bifröst and sees
> across all the realms, a fitting metaphor for a metrics/logs/alerting stack. It's a
> placeholder; **rename freely** (alternatives floated: *Vantage*, *Beacon*, *Cairn*).
> This file is the repo's `CLAUDE.md` **and** the brief for the agent generalizing and
> professionalizing this codebase. Read it top to bottom before touching anything.

---

## What it is

A **reusable, drop-in Infrastructure-as-Code template** that stands up a complete
observability stack — metrics, logs, and alerting — on a DigitalOcean VPC, reproducibly
and zero-trust by default. One `terraform apply` plus one `ansible-playbook` run gives any
team a Prometheus / Grafana / Loki / Alertmanager hub with Node Exporter + Promtail agents
on every node, reachable only over Tailscale.

**Positioning.** This is the productized artifact of **Brett Buskirk LLC's** *Cloud
Foundation* and *Observability Stack* services — a real, adoptable open-source template
that *is* the thing the consultancy delivers, the same way **AgentGate** productizes the
*Agentic Development Workflow* service. It does double duty: a tool used on real client
engagements **and** a portfolio piece ("here's the observability foundation I deploy,
as code"). Treat every reader as a potential client — the docs sell the rigor.

## Provenance — this is a generalization, not a greenfield build

This repo began as **`rcj-infra`**, a *real production deployment* that monitored the
"RC Journey" infrastructure (a WordPress site + a Foundry VTT instance on DigitalOcean).
That deployment is **decommissioned** — the infrastructure is torn down — but the IaC ran
in production and is solid. **The job is to generalize and professionalize it, not rebuild
it.** The Terraform modules, Ansible roles, and Docker Compose stack are good bones; they're
just wired to one specific, now-dead deployment. Your mission is to cut those org-specific
ties cleanly and turn this into something anyone can clone and deploy.

---

## The mission (two intertwined goals)

**Goal A — Generalize.** Strip every RC-Journey-specific assumption and turn the deployment
into a parameterized, configurable template. Nothing in the shipped template should mention
`rcj`, `rc-journey`, `foundry-vtt`, a specific VPC, region, or IP. A new user customizes a
handful of variables and gets a working stack.

**Goal B — Professionalize.** Bring the repo up to the same conventions as the rest of the
estate — rename, labels, milestones, a linked project board, a full documentation suite,
issue/PR templates, and CI that actually validates the IaC. Make it product-worthy.

Both goals ship in **independently-useful slices** (see *Phased build plan*). Each slice is
one or more PRs.

---

## Working conventions (non-negotiable)

This repo is governed by the same rules as the rest of `brett-buskirk`'s repos:

- **No direct commits to `main`.** `main` is protected by a branch ruleset. Work on a
  feature branch and open a PR with the `gh` CLI. The admin (Brett) can bypass in a pinch,
  but PR-first is the default. Self-merge is allowed once checks pass.
- **AgentGate runs on every PR** (`.github/workflows/agentgate.yml` is already here). Its
  config (`.agentgate.yml`) keeps `secrets` and `dangerous_patterns` as hard errors and
  `scope` as advisory. Expect — and it's fine — advisory warnings on large refactor PRs.
- **Conventional, scoped PRs.** Prefer a stack of focused PRs (one per phase/slice) over one
  giant diff. AgentGate's `diff_size` rule will warn past 30 files / 800 lines; that's a
  nudge to split, not a blocker.
- **Branch naming:** `feat/…`, `refactor/…`, `docs/…`, `ci/…`, `chore/…`.
- **Secrets never get committed.** `.gitignore` already covers `*.tfvars`, `.env`, `*.pem`,
  `*.key`, and generated inventory. Only ever commit `*.example` files. Verify before every
  push.

---

## Tech stack (keep it — it's the right stack)

| Layer | Technology |
|-------|-----------|
| Provisioning | **Terraform** (DigitalOcean provider ≥ 2.0), modular |
| Configuration | **Ansible** (roles + playbooks) |
| Runtime | **Docker** + Docker Compose |
| Metrics | **Prometheus** + **Node Exporter** |
| Logs | **Loki** + **Promtail** |
| Dashboards | **Grafana** (provisioned) |
| Alerting | **Alertmanager** (email / Slack / Discord receivers) |
| Access | **Tailscale** — zero-trust mesh, no public management ports |
| Cloud | **DigitalOcean** (VPC, Droplets, Cloud Firewall, Spaces) |

Image versions are pinned (Prometheus v2.51.0, Grafana 10.4.1, Loki/Promtail 2.9.6,
Alertmanager v0.27.0, Node Exporter v1.7.0). Keep them pinned; bump via Dependabot once
that's wired (see *Professional setup*).

---

## What "generic" means — design principles

1. **One name variable threads through everything.** Introduce a single `project_name`
   (a.k.a. `name_prefix`) Terraform variable and an Ansible equivalent. Every resource name,
   tag, hostname, Prometheus `external_labels.vpc`, Grafana folder/UID, project directory
   (`/opt/<project>-monitoring`), and alert subject derives from it. **Decouple the repo
   brand (Heimdall) from the deployment prefix** — a user deploying for "Acme" sets
   `project_name = "acme"` and never sees "heimdall" in their resources.

2. **App monitoring is data-driven, not hardcoded.** Today the stack hardcodes two specific
   apps (`rc-journey-wp`, `foundry-vtt`) into Prometheus targets, alert rules, the Grafana
   dashboard, and the Promtail scrape config. The template must instead drive monitored
   targets from a **list/map variable** (e.g. `monitored_nodes = [{ name, private_ip, role,
   labels }]`), with a **generic host dashboard** and **generic node-health alerts**. Ship
   the WordPress/Foundry specifics as an **optional example overlay**, not the default.

3. **Sane, safe defaults; nothing required that can be defaulted.** A user should get a
   working single-node stack with minimal input. Defaults must be generic (`region = "nyc3"`
   is fine as a default; `vpc_name` must NOT default to `rcj-vpc-nyc3`). Security defaults
   should be safe — e.g. don't default `ssh_allowed_ips` to `0.0.0.0/0`; require it, or
   document the risk loudly.

4. **Multi-environment ready.** Restructure `terraform/environments/production/` so a user
   can stamp out `staging`/`dev` (or use workspaces) without copy-paste divergence. At
   minimum provide an `environments/example/` that's the documented starting point.

5. **Everything customizable is documented.** Every variable has a description and appears in
   a `CUSTOMIZATION.md` walkthrough ("deploy Heimdall for your org in 15 minutes").

---

## Generalization plan — the hardcoded inventory

A full audit produced the inventory below. **Do not trust it as exhaustive at execution
time** — re-run the sweep first, since line numbers drift:

```bash
# The canonical "what's still org-specific" sweep — should return ZERO hits in shipped
# template files (an example/ overlay may legitimately still reference wordpress/foundry):
grep -rniE 'rcj|rc-journey|rcjourney|foundry|wordpress|rcj-vpc|10\.108\.0\.|nyc3' . \
  --include='*.tf' --include='*.tfvars*' --include='*.yml' --include='*.yaml' \
  --include='*.yml.j2' --include='*.json' --include='*.sh' --include='*.md' \
  | grep -v '.git/' | grep -v '/example/'
```

**Categories to parameterize (representative locations — verify before editing):**

| Category | What's hardcoded | Where (representative) | Target |
|---|---|---|---|
| Project/VPC name | `rcj-vpc-nyc3`, `rcj-management`, `rcj-infra` tags | `terraform/environments/production/{variables.tf,main.tf}`, `terraform.tfvars.example` | `var.project_name` / `var.vpc_name` (no org default) |
| Log bucket | `rcj-logs-nyc3` | `variables.tf:61`, `.env.example:40` | derive from `project_name` or own var |
| Prometheus labels | `external_labels.vpc: rcj-vpc-nyc3`, `instance: 'rcj-management'` | `docker/monitoring/prometheus/prometheus.yml`, `ansible/roles/monitoring-stack/templates/prometheus.yml.j2` | templated from `project_name` |
| Monitored apps | `rc-journey-wp`, `foundry-vtt`, hardcoded IPs `10.108.0.2/.3` | `prometheus.yml(.j2)`, `prometheus/alerts.yml`, `inventory/manual.yml` | `monitored_nodes` list var |
| Alert rules | `WordPressDown`, `FoundryVTTDown` | `docker/monitoring/prometheus/alerts.yml`, `ansible/roles/monitoring-stack/files/alerts.yml` | generic node-health alerts + example overlay |
| Grafana | folder "RCJ Infrastructure", UID `rcj-infra`/`rcj-overview`, app-specific panels | `grafana/provisioning/dashboards/`, `ansible/.../files/*.json` | generic host dashboard, name from `project_name` |
| Promtail | hostname checks for `wordpress`/`wp`/`foundry`, app log paths | `ansible/roles/promtail-agent/templates/promtail-config.yml.j2` | generic journald/syslog; app overlays opt-in |
| Project dir | `/opt/rcj-monitoring` (5+ places) | `ansible/group_vars/all.yml`, `playbooks/*.yml`, `roles/common/tasks/main.yml`, `scripts/deploy.sh` | `/opt/{{ project_name }}-monitoring` |
| Network | VPC CIDR `10.108.0.0/20` hardcoded in UFW rules | `ansible/group_vars/all.yml:16`, `roles/security`, `roles/node-exporter` | `var.vpc_cidr` / discovered |
| Region | `nyc3` defaults | `variables.tf:34`, `.env.example:41` | OK as default, but documented |
| Email/domain | `alerts@yourdomain.com`, `grafana.yourdomain.com` | alertmanager configs, `variables.tf:86` | already placeholders — keep, document |
| Email subject | `[RCJ-Infra]` | `docker/monitoring/alertmanager/alertmanager.yml:63` | `[{{ project_name }}]` |

**Approach:** Terraform side first (variables + module wiring), then Ansible (group_vars +
templated roles), then the static `docker/monitoring/` configs (which are the
"run-it-by-hand" path and should mirror the Ansible-templated output). The Ansible Jinja2
templates are the source of truth for the deployed configs; the `docker/monitoring/*` static
files are a parallel manual path — keep them consistent or consider generating them.

---

## Professional setup — conventions to apply

Mirror **`~/github-repos/agent-gate`** (the closest analog: a shipped infra/tooling product)
and **`~/github-repos/day-one`**. Both are on disk — read them directly for exact formats.

### Documentation suite
- **`README.md`** — rewrite generic. Badges (CI, license, optionally Terraform Registry
  later), one-paragraph pitch, architecture diagram (the existing ASCII diagram is good —
  degenericize labels), prerequisites, quickstart, security model, teardown, maintenance.
  Link `CUSTOMIZATION.md`, `ARCHITECTURE.md`, `CONTRIBUTING.md`.
- **`ARCHITECTURE.md`** (or `docs/DESIGN.md`) — the design source of truth: components, the
  data-flow diagram, the Tailscale zero-trust model, the variable/parameter model, and the
  decisions behind them (mirror agent-gate's `docs/DESIGN.md`).
- **`CUSTOMIZATION.md`** — *the* differentiator. Step-by-step "deploy for your org": set
  `project_name`, fill `terraform.tfvars`, define `monitored_nodes`, run apply + playbook,
  reach Grafana over Tailscale. Include a worked example.
- **`CONTRIBUTING.md`** — branch→PR workflow, the validation gates (fmt/validate/lint), how
  to add a monitored-node type or a dashboard, conventions. Model on agent-gate's.
- **`SECURITY.md`** — supported versions, private-advisory reporting flow, scope (no secrets
  committed, Tailscale-only management surface, firewall posture).
- **`CHANGELOG.md`** — [Keep a Changelog](https://keepachangelog.com/) + SemVer. Seed it with
  an `## [Unreleased]` and a note that this is a generalization of a production deployment.
- **`ROADMAP.md`** — phased, checkbox-driven (mirror agent-gate's), tracking the generalize +
  professionalize phases and post-1.0 ideas (remote state, HA, more cloud providers).
- **`LICENSE`** — **MIT**, `© 2026 Brett Buskirk` (consistent with day-one and agent-gate).
- Keep a plain-language **`docs/ABOUT.md`** ("what this is, why observability-as-code
  matters," no jargon) — agent-gate has one; it's a nice on-ramp for non-engineer readers.

### `.github/`
- **Issue templates** (`ISSUE_TEMPLATE/`, YAML form style, `blank_issues_enabled: false`):
  `bug_report.yml`, `feature_request.yml`, and an infra-flavored
  `support_request.yml` *("trouble deploying")*. Auto-apply `needs-triage`. Add a
  `config.yml` with contact links to the README/CUSTOMIZATION docs.
- **`pull_request_template.md`** — "What & why", type-of-change checklist (terraform /
  ansible / docker / docs / ci), and a checklist (`terraform fmt`/`validate` clean,
  `ansible-lint` clean, no secrets, docs updated).
- **`dependabot.yml`** — `github-actions` (monthly) and `terraform` (monthly) ecosystems;
  group minor/patch; ignore majors. (Docker image bumps can be tracked manually or via a
  later addition.)

### CI / validation — the "tests" for IaC
This repo currently has **only** the AgentGate workflow. Add a real validation pipeline
(`.github/workflows/ci.yml`, on push to `main` + PRs) — these are the equivalent of
day-one's typecheck/test/build gate:
- `terraform fmt -check -recursive`
- `terraform validate` (per environment / root module; `terraform init -backend=false`)
- **`tflint`** (with the DigitalOcean ruleset if available)
- **`ansible-lint`** over `ansible/`
- **`yamllint`** over the YAML configs
- optionally **`shellcheck`** over `scripts/*.sh`
Keep AgentGate as a separate job/workflow (already present). These gates must pass before
merge once added.

### GitHub-side: labels, milestones, project board
- **Labels** — keep GitHub defaults; add a custom taxonomy adapted for IaC (use `gh label
  create`; colors cribbed from agent-gate/day-one):
  `terraform` · `ansible` · `docker` · `monitoring` · `security` · `documentation` (default)
  · `ci` · `chore` · `dependencies` · `needs-triage` · `approved` · `release` · `breaking`.
- **Milestones** — version-style, one per phase, mirroring agent-gate
  (`gh api repos/:owner/:repo/milestones`):
  `v0.1.0 — Generalize Terraform`, `v0.2.0 — Generalize Ansible`,
  `v0.3.0 — App-agnostic monitoring`, `v0.4.0 — Docs & examples`,
  `v0.5.0 — CI & validation`, `v1.0.0 — Template release`.
- **Project board** — create a repo-linked GitHub Project (v2) named after the repo (there's
  already a per-product project pattern: "AgentGate", "Day One", …). Add a board view with
  Todo / In progress / Done, and file an issue per phase task, assigned to its milestone and
  added to the board. `gh project create --owner brett-buskirk --title "Heimdall"`, then link
  it and add items.

### Repo metadata
Set a generic description, topics, and (optionally) a homepage:
```
gh repo edit brett-buskirk/<newname> \
  --description "Drop-in observability stack for DigitalOcean — Prometheus, Grafana, Loki, Alertmanager on a Tailscale-secured VPC, provisioned with Terraform + Ansible." \
  --add-topic terraform --add-topic ansible --add-topic observability \
  --add-topic prometheus --add-topic grafana --add-topic loki \
  --add-topic digitalocean --add-topic infrastructure-as-code \
  --add-topic devops --add-topic monitoring --add-topic tailscale
```

---

## Target repo structure (after conversion)

```
<heimdall>/
├── README.md  ARCHITECTURE.md  CUSTOMIZATION.md  CONTRIBUTING.md
├── SECURITY.md  CHANGELOG.md  ROADMAP.md  LICENSE  CLAUDE.md
├── .github/
│   ├── ISSUE_TEMPLATE/{config.yml,bug_report.yml,feature_request.yml,support_request.yml}
│   ├── pull_request_template.md
│   ├── dependabot.yml
│   └── workflows/{ci.yml, agentgate.yml}
├── docs/{ABOUT.md, assets/…}
├── terraform/
│   ├── environments/example/        # documented starting point (was production/)
│   └── modules/{droplet,firewall,spaces-bucket}/
├── ansible/{playbooks,roles,group_vars,inventory}/
├── docker/monitoring/               # manual/run-by-hand path; mirrors Ansible output
├── examples/
│   └── wordpress-foundry/           # the OLD rcj specifics, preserved as an example overlay
└── scripts/{deploy.sh, setup-tailscale.sh, preflight.sh(new)}
```

---

## Phased build plan (each phase = independently useful, maps to a milestone)

**Phase 0 — Rename & scaffold conventions.** Rename the repo (see below). Add `LICENSE`,
`CHANGELOG`, `ROADMAP`, `CONTRIBUTING`, `SECURITY`, the `.github/` templates, labels,
milestones, and the project board. Set repo metadata/topics. (Docs can start as stubs and
fill in over later phases.)

**Phase 1 — Generalize Terraform.** Introduce `project_name`; remove every org default;
rename `environments/production` → `environments/example`; thread the name through resources,
tags, outputs; safe security defaults. `terraform validate` + `fmt` clean.

**Phase 2 — Generalize Ansible.** Parameterize `group_vars/all.yml` (`project_name`,
`vpc_cidr`, project dir); degenericize roles and the Jinja2 templates; generic inventory
example. `ansible-lint` clean.

**Phase 3 — App-agnostic monitoring.** Replace hardcoded apps with `monitored_nodes`-driven
Prometheus targets; generic host dashboard; generic node-health alert rules; generic Promtail
config. Move WordPress/Foundry specifics to `examples/wordpress-foundry/`.

**Phase 4 — Docs & examples.** Rewrite README generic; write ARCHITECTURE, CUSTOMIZATION,
ABOUT; document every variable; the worked example.

**Phase 5 — CI & validation.** Add the `ci.yml` validation pipeline (fmt/validate/tflint/
ansible-lint/yamllint/shellcheck) and dependabot.

**Phase 6 — Polish & v1.0.** Preflight script, teardown/runbook polish, screenshots/diagram,
tag `v1.0.0`, write the release notes. (Optional later: Terraform Registry publish, remote
state backend guide, second cloud provider.)

---

## Definition of Done (v1.0)

A new user can `git clone`, read `CUSTOMIZATION.md`, set `project_name` + a short
`terraform.tfvars` + a `monitored_nodes` list, run `terraform apply` then the Ansible
playbooks, and reach a working Grafana/Prometheus/Loki/Alertmanager stack over Tailscale —
**with zero references to `rcj`/`rc-journey`/`foundry`/`wordpress` anywhere in the shipped
template** (the org-specific grep returns clean outside `examples/`). The repo has the full
docs suite, labels, milestones, a linked project board, issue/PR templates, a green CI
validation pipeline, a `LICENSE`, and a tagged `v1.0.0` release. AgentGate is green on the
final PR.

---

## Renaming the repo

1. Pick the name (default recommendation: **heimdall**; confirm with Brett first — it threads
   through docs, topics, and the project board).
2. `gh repo rename <newname> -R brett-buskirk/rcj-infra` (GitHub auto-redirects the old URL).
3. Update the local remote: `git remote set-url origin git@github.com:brett-buskirk/<newname>.git`,
   and rename the local directory to match.
4. Find-replace `rcj-infra` in docs/links (README footer, any badges) — but **only after**
   the generalization passes, so you're not chasing a moving target.
5. The branch-protection ruleset and AgentGate workflow follow the repo automatically; no
   reconfiguration needed.

---

## Decisions

**Resolved**
- **Stack** — unchanged (Terraform + Ansible + Docker Compose; Prometheus/Grafana/Loki/
  Alertmanager; DigitalOcean; Tailscale). It's the right stack; don't re-platform.
- **License** — MIT, © 2026 Brett Buskirk.
- **Old app specifics** — preserved as an `examples/` overlay, not deleted (they're a useful
  worked example of monitoring a real app), but removed from the default path.
- **Workflow** — branch → PR → green checks → merge; AgentGate gates every PR.

**To confirm with Brett**
- **The name** — "Heimdall" is the working recommendation; lock it before Phase 0's rename.
- **Default region** — keep `nyc3` as the default, or leave region required/unset?
- **Remote state** — ship a documented remote-state backend (Spaces/S3) in v1.0, or defer to
  post-1.0? (Local state is fine for a template; teams will want remote.)

---

## Reference repos (read these for exact conventions)

- **`~/github-repos/agent-gate`** — the closest model. Mirror its `CHANGELOG`, `ROADMAP`,
  `CONTRIBUTING`, `SECURITY`, `docs/{ABOUT,DESIGN,RELEASING}`, `.github/` templates, label
  taxonomy, milestone-per-version, and dependabot config.
- **`~/github-repos/day-one`** — mirror its CI-gate discipline (validate → lint → build as
  required checks), its YAML-form issue templates, and its `CLAUDE.md` shape.

When in doubt, match what those two repos already do — consistency across the estate is a
goal in itself (a shared formatting/setup guide for all repos is planned next).
