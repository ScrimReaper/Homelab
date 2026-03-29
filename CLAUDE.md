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
- **UFW on k3s nodes**: UFW is intentionally skipped on k3s nodes — the `common` role gates the UFW block with `when: inventory_hostname not in groups['k3s_cluster']`. k3s nodes are on a private LAN and services are exposed via Cluster-internal mechanisms, so host-level firewalling adds complexity without benefit.

## Known Issues / Tech Debt

- **k3s-ansible 1.2.0 breaks vault-encrypted `token`**: PR #509 in k3s-ansible replaced Jinja2 templates with `to_nice_yaml` for writing `/etc/rancher/k3s/config.yaml`. This causes `AnsibleVaultEncryptedUnicode` objects to be serialized as `!vault |` ciphertext instead of being decrypted, so k3s uses the raw ciphertext as its cluster secret. Pinned to `1.1.1` in `requirements.yml` as workaround. Upstream issue + fix pending — see `docs/runbooks/ansible-setup.md`.

## Conventions

- All manifests live under `k8s/`
- Document decisions and migrations in `docs/`
