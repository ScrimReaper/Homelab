# Homelab

Personal homelab running a k3s cluster on Raspberry Pis.

## Hardware

| Device | Hostname | Role | Specs |
|--------|----------|------|-------|
| Raspberry Pi 5 Model B Rev 1.1 | `jellypi` | k3s server (control plane) | ARM Cortex-A76, 64-bit, 8GB RAM, Debian Bookworm |
| Raspberry Pi 4 | `cherrypi` | k3s agent (worker) | ARM Cortex-A72, 64-bit |
| Raspberry Pi Zero | TBD | Not part of cluster | ARMv6, 512MB RAM |

### Pi 5 Storage

| Device | Size | Mount | Notes |
|--------|------|-------|-------|
| `mmcblk0` (SD card) | 57.6G | `/` | OS + boot |
| `sda` → `media` (SSD) | 931.5G | `/mnt/media` | SanDisk Extreme Portable, LUKS encrypted, Jellyfin media library |

## Services

| Service | Status | Notes |
|---------|--------|-------|
| Jellyfin | Running on Pi 5 | To be migrated into cluster |
| Pi-hole | Running on Pi 4 | To be migrated into cluster |
| Immich | Running on main PC | Migration pending — needs storage strategy for 1TB photo library |
| Torrenting stack | Planned | qBittorrent + Sonarr + Radarr + Prowlarr |

## Goals

- [ ] Set up k3s cluster (Pi 5 as server, Pi 4 as agent)
- [ ] Migrate all services into the cluster
- [ ] Expose services to the internet
- [ ] Immich storage migration (1TB photo library)

## Repository Structure

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

## Docs

- [ADR-001 — k3s over full Kubernetes](docs/adr/001-k3s.md)
- [ADR-002 — Immich storage: physical SSD attachment](docs/adr/002-immich-storage.md)
- [ADR-003 — Dedicated NAS for cluster storage](docs/adr/003-nas-storage.md)
- [ADR-004 — IaC tooling: Ansible + Helm + FluxCD](docs/adr/004-iac-tooling.md)
