# Contributing to Heimdall

Contributions that improve the template's generality, correctness, or documentation are welcome.

## Workflow

1. Fork the repo and create a branch: `git checkout -b feat/my-change`
2. Make your changes (see conventions below)
3. Run the validation gates locally (see below) — all must pass
4. Push and open a PR against `main`
5. CI runs `terraform fmt`, `terraform validate`, `tflint`, `ansible-lint`, `yamllint`, and `shellcheck`; AgentGate also runs on your PR

## Validation gates (run before pushing)

```bash
# Terraform
terraform fmt -check -recursive terraform/
terraform -chdir=terraform/environments/example init -backend=false
terraform -chdir=terraform/environments/example validate

# Ansible
ansible-lint ansible/

# YAML
yamllint .

# Shell
shellcheck scripts/*.sh
```

## Conventions

- **No org-specific strings in template files.** The canonical check is in `CLAUDE.md`. Run it before opening a PR — it must return zero hits outside `examples/`.
- **One `project_name` variable threads through everything.** Resource names, tags, directories, alert subjects — all derive from it. Don't add a new hardcoded name.
- **`monitored_nodes` drives all app targets.** Don't add hardcoded Prometheus targets, alert rules, or Grafana panels for a specific app. Put them in `examples/` instead.
- **Secrets never get committed.** Only ever commit `*.example` files. `.gitignore` covers `*.tfvars`, `.env`, `*.pem`, `*.key`, and generated inventory — verify before every push.
- **Every variable has a description.** If you add a Terraform or Ansible variable, document it in the variable block and in `CUSTOMIZATION.md`.

## Adding a new monitored-node type

1. Add your app-specific Prometheus targets to `examples/<your-app>/prometheus-overlay.yml`
2. Add app-specific alert rules to `examples/<your-app>/alerts-overlay.yml`
3. Add app-specific Promtail scrape jobs to `examples/<your-app>/promtail-overlay.yml`
4. Document the overlay pattern in `CUSTOMIZATION.md`

## Adding a Grafana dashboard

1. Export the dashboard JSON from Grafana
2. Place it in `ansible/roles/monitoring-stack/files/dashboards/`
3. Register it in `ansible/roles/monitoring-stack/files/grafana-dashboards.yml`
4. Keep the dashboard generic — use template variables for instance/job selectors, not hardcoded names

## Branch naming

`feat/…`, `refactor/…`, `docs/…`, `ci/…`, `chore/…`
