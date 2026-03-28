# Homelab

Mo's homelab — a k3s cluster on Raspberry Pis with self-hosted services.

## Hardware

| Device | Role (target) | Notes |
|--------|--------------|-------|
| Raspberry Pi 5 Model B Rev 1.1 | k3s server (control plane) | hostname: `jellypi`, 8GB RAM, Debian Trixie, 1TB LUKS-encrypted SSD at `/mnt/media` |
| Raspberry Pi 4 | k3s agent (worker) | hostname: `cherrypi`, Raspberry Pi OS Lite 64-bit (Debian Trixie), currently running Pi-hole |
| Raspberry Pi Zero | TBD — not part of cluster | ARMv6, too weak for k3s |

## Services

| Service | Target | Current Status |
|---------|--------|----------------|
| Jellyfin | k3s cluster | Running on Pi 5, local-only |
| Pi-hole | k3s cluster | Running on Pi 4, local-only |
| Immich | k3s cluster | Running on main PC (1TB SSD for photos) — migration pending |
| Torrenting stack | k3s cluster | Planned (qBittorrent + Sonarr + Radarr + Prowlarr) |

## Goals

- [x] Set up k3s cluster (Pi 5 as server, Pi 4 as agent)
- [ ] Migrate Jellyfin into cluster
- [ ] Migrate Pi-hole into cluster
- [ ] Migrate Immich into cluster (needs storage strategy for 1TB photo library)
- [ ] Deploy torrenting stack (qBittorrent, Sonarr, Radarr, Prowlarr)
- [ ] Expose services to the internet

## Architecture Decisions

- **Internet exposure strategy**: TBD (candidates: Cloudflare Tunnel, Tailscale, port forwarding + DDNS)
- **Storage**: Immich migration requires a plan for the 1TB photo library currently on main PC
- **LUKS unlock**: vault passphrase for now; migrate to Tang/NBDE once a VPN is set up between nodes

## Known Issues / Tech Debt

- **UFW conflicts with k3s**: The UFW hardening in the common role blocks k3s inter-node ports. Needs refactoring to either exclude k3s nodes from UFW or open the required ports (6443, 8472/udp, 10250, 51820-51821/udp) before enabling UFW.

## Conventions

- All manifests live under `k8s/`
- Document decisions and migrations in `docs/`
