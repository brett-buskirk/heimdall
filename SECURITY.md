# Security Policy

## Supported Versions

| Version | Supported |
|---------|-----------|
| 0.x     | Yes       |

## Reporting a Vulnerability

Please do **not** file a public GitHub issue for security vulnerabilities.

Report them privately via [GitHub's private vulnerability reporting](https://github.com/brett-buskirk/heimdall/security/advisories/new).

Include:
- A description of the vulnerability
- Steps to reproduce
- Potential impact

You'll receive a response within 48 hours. Valid reports will be credited in the release notes unless you prefer anonymity.

## Scope

Heimdall is an Infrastructure-as-Code template. Key security considerations:

- **No secrets committed.** Only `*.example` files are tracked. Real credentials (`*.tfvars`, `.env`, `*.pem`, `*.key`, generated inventory) are gitignored.
- **Tailscale-only management surface.** No management ports (SSH, Grafana, Prometheus, Loki) are exposed to the public internet. All access is over the Tailscale mesh — Tailscale auth is the perimeter.
- **Cloud Firewall defaults to deny.** The Terraform firewall module allows only VPC-internal traffic on monitoring ports and SSH from explicitly specified IPs.
- **VPC isolation.** Monitoring traffic between nodes stays on the private VPC network; it never leaves DigitalOcean's internal fabric.
- **Image versions are pinned.** Docker image tags are explicit and pinned; Dependabot monitors for updates.
