# Homelab

Personal homelab running a k3s cluster on Raspberry Pis.

## Hardware

| Device | Hostname | Role | Specs |
|--------|----------|------|-------|
| Raspberry Pi 5 Model B Rev 1.1 | `jellypi` | k3s server (control plane) | ARM Cortex-A76, 64-bit, 8GB RAM, Debian Trixie |
| Raspberry Pi 4 | `cherrypi` | k3s agent (worker) | ARM Cortex-A72, 64-bit, Raspberry Pi OS Lite 64-bit (Debian Trixie) |
| Raspberry Pi Zero | TBD | Not part of cluster | ARMv6, 512MB RAM |
| VPS (1984 Hosting) | `argonath` | VPN entry/exit node | 1 vCPU, 2GB RAM, 50GB SSD, Debian |

### Pi 5 Storage

| Device | Size | Mount | Notes |
|--------|------|-------|-------|
| `mmcblk0` (SD card) | 57.6G | `/` | OS + boot |
| `sda` → `media` (SSD) | 931.5G | `/mnt/media` | SanDisk Extreme Portable, LUKS encrypted, Jellyfin media library |

## Services

| Service | Status | Notes |
|---------|--------|-------|
| Jellyfin | Running on Pi 5 | To be migrated into cluster |
| Pi-hole | Running in cluster on cherrypi | DNS + DHCP, hostNetwork mode |
| Immich | Running on main PC | Migration pending — needs storage strategy for 1TB photo library |
| Torrenting stack | Planned | qBittorrent + Sonarr + Radarr + Prowlarr |

## Goals

- [x] Set up k3s cluster (Pi 5 as server, Pi 4 as agent)
- [x] Set up Flux GitOps
- [x] Deploy MetalLB, Traefik, Pi-hole
- [ ] Migrate Jellyfin into cluster
- [ ] Migrate Immich into cluster (needs storage strategy for 1TB photo library)
- [ ] Set up NFS shared storage from jellypi's SSD
- [ ] Expose services to the internet (Cloudflare Tunnel)
- [ ] Migrate LUKS unlock to Tang/NBDE (network-bound, requires VPN)
- [ ] Set up VPN cluster (argonath as entry/exit node — ADR pending)

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

### ADRs
- [ADR-001 — k3s over full Kubernetes](docs/adr/001-k3s.md)
- [ADR-002 — Immich storage: physical SSD attachment](docs/adr/002-immich-storage.md)
- [ADR-003 — Dedicated NAS for cluster storage](docs/adr/003-nas-storage.md)
- [ADR-004 — IaC tooling: Ansible + Helm + FluxCD](docs/adr/004-iac-tooling.md)
- [ADR-005 — Flux repository structure and secret management](docs/adr/005-gitops-structure.md)
- [ADR-006 — Bare-metal networking and storage strategy](docs/adr/006-networking-storage.md)

### Runbooks
- [Ansible setup](docs/runbooks/ansible-setup.md)
- [Flux GitOps setup](docs/runbooks/flux-setup.md)
- [Gotchas](docs/runbooks/gotchas.md)
