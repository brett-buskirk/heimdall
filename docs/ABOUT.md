# What is Heimdall? (the plain-language version)

**Heimdall is a ready-to-deploy observability stack for your cloud infrastructure.**

If your team runs servers on DigitalOcean and wants to know when something breaks — before your users tell you — this page explains what Heimdall is and why it exists, without the technical jargon. (Engineers: the [README](../README.md) and [ARCHITECTURE](../ARCHITECTURE.md) have the details.)

---

## The short version

When you're running infrastructure in the cloud, things fail: a server runs out of disk space, a service crashes, CPU spikes and the site slows down. The question is whether *you* find out first, or your users do.

Heimdall is an **observability stack** — a set of tools wired together to continuously watch your servers, collect metrics and logs, and send you an alert the moment something looks wrong. It's the difference between being reactive (something broke, now fix it) and proactive (I got paged at 2am, restarted the service, and my users never noticed).

**What makes Heimdall different** is that it's packaged as Infrastructure-as-Code: the entire stack is defined in configuration files you can version-control, review, and reproduce. One command stands it up; another tears it down. There's no "it works on my machine" and no undocumented manual steps.

---

## What it sets up

A working Heimdall deployment gives you:

| What you get | What it does |
|---|---|
| **Prometheus** | Collects metrics from every server — CPU, memory, disk, network — on a schedule |
| **Grafana** | Dashboards so you can see those metrics in a browser, at a glance |
| **Loki** | Aggregates logs from all your servers into one searchable place |
| **Alertmanager** | Sends you an email, Slack message, or Discord ping when something crosses a threshold |
| **Node Exporter** | The small agent that runs on each server and exposes its metrics for Prometheus to collect |
| **Promtail** | The small agent that ships each server's logs to Loki |

All of it is reachable only over **Tailscale** — a private, encrypted network — so none of your monitoring infrastructure is exposed to the public internet.

---

## Who it's for

**Small engineering teams and startups** running infrastructure on DigitalOcean who want production-grade observability without the operational overhead of building it from scratch — or paying for a managed observability platform.

Heimdall is also the observability foundation that [Brett Buskirk LLC](https://brett-buskirk.dev) deploys as part of its *Cloud Foundation* and *Observability Stack* services. This is the actual thing, open-sourced.

---

## How it works in practice

1. You fill in a short configuration file: your project name, your DigitalOcean region, and a list of the servers you want to monitor.
2. One command (`terraform apply`) provisions the monitoring server in your DigitalOcean VPC.
3. One command (`ansible-playbook`) installs and configures the full stack on that server, and deploys the lightweight agents to every node being monitored.
4. You open Grafana over Tailscale and see your infrastructure, live.

The [CUSTOMIZATION.md](../CUSTOMIZATION.md) guide walks through this step by step.

---

## Want the technical details?

- **[README](../README.md)** — prerequisites, quickstart, security model
- **[ARCHITECTURE](../ARCHITECTURE.md)** — how the components fit together and why
- **[CUSTOMIZATION.md](../CUSTOMIZATION.md)** — deploy Heimdall for your org in 15 minutes
- **[ROADMAP](../ROADMAP.md)** — what's coming next
