# ADR-004 — IaC tooling: Ansible + Helm + FluxCD

**Date:** 2026-03-25
**Status:** Decided

## Context

The homelab needs a reproducible, version-controlled way to manage both node configuration and cluster workloads. Several IaC tools exist but operate at different layers — the right answer is a combination rather than a single tool.

## Decision

Use a three-layer IaC stack:

| Layer | Tool | Scope |
|-------|------|-------|
| OS & node provisioning | Ansible | Install k3s, configure OS, mount drives, manage users/SSH |
| Kubernetes app packaging | Helm | Package applications via community charts with custom values |
| Cluster GitOps | FluxCD | Watches this git repo and reconciles cluster state automatically |

## Reasoning

**Ansible** is the natural fit for bare metal provisioning. It is agentless, SSH-based, and already familiar from other projects. It handles everything below the Kubernetes API — OS packages, k3s installation, LUKS unlocking, drive mounts.

**Helm** provides access to community-maintained charts for all target services (Jellyfin, Immich, Pi-hole, qBittorrent, Sonarr, Radarr, Prowlarr). Values files in this repo capture configuration.

**FluxCD** is preferred over ArgoCD for this setup due to its lower resource footprint — important on Raspberry Pi hardware. Flux runs as lightweight controllers in the cluster and polls this git repo (~1 min interval), applying any drift between git and cluster state automatically. The repo becomes the single source of truth.

## Rejected alternatives

- **Terraform/OpenTofu** — suited for cloud infrastructure provisioning, not bare metal. May be introduced later for managing Cloudflare DNS when services are exposed to the internet.
- **NixOS** — fully declarative and reproducible, but Pi support is less mature and the learning curve is high relative to the benefit here.
- **ArgoCD** — more feature-rich than Flux (better UI) but significantly heavier on resources. Not a good fit for Pi-class hardware.

## Repository structure

```
.
├── ansible/              # Playbooks for node provisioning
│   ├── inventory.yml
│   └── roles/
├── docs/                 # ADRs and runbooks
└── k8s/                  # Kubernetes manifests (managed by Flux)
    ├── flux/             # Flux bootstrap configuration
    ├── apps/             # HelmRelease per application
    └── infrastructure/   # Shared infra (ingress, storage, etc.)
```

## Consequences

- All cluster changes go through git — no manual `kubectl apply` in normal operation
- Ansible playbooks must be run to provision new nodes before they join the cluster
- Flux reconciliation means the cluster self-heals to match git state — accidental manual changes get reverted
- This setup directly mirrors production Kubernetes workflows, making it relevant as a thesis reference point
