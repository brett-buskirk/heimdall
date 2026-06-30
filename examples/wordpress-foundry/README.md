# Example Overlay: WordPress + Foundry VTT

This directory contains the application-specific monitoring config that was used
in the original `rcj-infra` deployment (a WordPress site + a Foundry VTT instance
on DigitalOcean). It serves as a worked example of how to extend the generic
Heimdall template for specific apps.

## What's here

| File | Purpose |
|---|---|
| `alerts.yml` | Prometheus alert rules for WordPress and Foundry VTT availability |
| `promtail-extra-jobs.yml` | Promtail scrape jobs for Apache/WordPress logs and Foundry Docker logs |

## How to use

### Alerts

Add `examples/wordpress-foundry/alerts.yml` as a second rule file in your
`prometheus.yml`:

```yaml
rule_files:
  - /etc/prometheus/alerts.yml                         # generic node-health
  - /etc/prometheus/wordpress-foundry-alerts.yml       # app-specific
```

Copy the file alongside your main alerts file, or merge the rules into a single
`alerts.yml`. Update the `instance` label values to match your Prometheus
scrape target names.

### Promtail log jobs

Add the relevant jobs from `promtail-extra-jobs.yml` to the `scrape_configs`
block of `promtail-config.yml.j2` on nodes that run those apps. The file
includes comments showing how to wire this up conditionally via a
`promtail_extra_jobs` host variable.
