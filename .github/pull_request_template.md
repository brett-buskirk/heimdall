## What & why

<!-- Describe the change and link the issue it resolves -->

Closes #

## Type of change

- [ ] Terraform
- [ ] Ansible
- [ ] Docker / monitoring stack
- [ ] Documentation
- [ ] CI / validation
- [ ] Chore / refactor

## Checklist

- [ ] `terraform fmt -check -recursive` passes
- [ ] `terraform validate` passes (per changed environment/module)
- [ ] `ansible-lint` passes
- [ ] `yamllint` passes
- [ ] `shellcheck` passes (if `.sh` files changed)
- [ ] No secrets committed — only `*.example` files
- [ ] Org-specific grep returns zero hits outside `examples/` (see `CLAUDE.md` for the command)
- [ ] Docs updated if behavior or variables changed
