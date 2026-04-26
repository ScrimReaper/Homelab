# Homelab

Mo's homelab — a k3s cluster on Raspberry Pis with self-hosted services.

## Hardware

| Device | Role (target) | Notes |
|--------|--------------|-------|
| Raspberry Pi 5 Model B Rev 1.1 | k3s server (control plane) | hostname: `jellypi`, 8GB RAM, Debian Trixie, 1TB LUKS-encrypted SSD at `/mnt/media` |
| Raspberry Pi 4 | k3s agent (worker) | hostname: `cherrypi`, Raspberry Pi OS Lite 64-bit (Debian Trixie) |
| Raspberry Pi Zero W | Pi-hole (dedicated, not in cluster) | hostname: `blueberrypi`, ARMv6, 32-bit Raspberry Pi OS Lite (Debian Trixie), too weak for k3s |
| VPS (1984 Hosting) | VPN entry/exit node | hostname: `argonath`, 1 vCPU, 2GB RAM, 50GB SSD, Debian, hosted at 1984hosting.com |

## Services

| Service | Target | Current Status |
|---------|--------|----------------|
| Jellyfin | k3s cluster | Running on Pi 5, local-only |
| Pi-hole | blueberrypi (dedicated hardware) | Running on blueberrypi |
| Immich | k3s cluster | Running on main PC (1TB SSD for photos) — migration pending |
| Torrenting stack | k3s cluster | Planned (qBittorrent + Sonarr + Radarr + Prowlarr) |

## Goals

- [x] Set up k3s cluster (Pi 5 as server, Pi 4 as agent)
- [ ] Migrate Jellyfin into cluster
- [x] Migrate Pi-hole to blueberrypi (dedicated hardware, see ADR-008)
- [ ] Migrate Immich into cluster (needs storage strategy for 1TB photo library)
- [ ] Deploy torrenting stack (qBittorrent, Sonarr, Radarr, Prowlarr)
- [x] Set up VPN (Headscale on argonath, Tailscale on jellypi + cherrypi)
- [x] Set up ProtonVPN exit node (jellypi routes tailnet traffic through ProtonVPN — see ADR-009)
- [ ] Expose services to the internet (cloudflared deployed — see ADR-010; pending first public service)

## Architecture Decisions

- **Operator access strategy**: Tailscale + self-hosted Headscale on argonath — see ADR-008
- **Public exposure strategy**: Cloudflare Tunnel (cloudflared → Traefik → Ingress); Pangolin is the long-term self-hosted goal — see ADR-010
- **Identity / SSO**: Authelia as OIDC provider and Traefik forward-auth gateway; file-based user backend, SQLite session store, Authentik is the documented upgrade path — see ADR-011
- **VPN cluster**: argonath (VPS on 1984 Hosting) runs Headscale as the control plane — see ADR-008
- **Storage**: Immich migration requires a plan for the 1TB photo library currently on main PC
- **LUKS unlock**: vault passphrase for now; VPN is in place so Tang/NBDE migration is unblocked
- **UFW**: opt-in via the `ufw` inventory group — only hosts in that group get UFW applied (currently: argonath). k3s nodes are on a private LAN and services are exposed via cluster-internal mechanisms, so host-level firewalling adds complexity without benefit.

## Goals (Infrastructure)

- [x] Set up Flux GitOps
- [x] Deploy MetalLB
- [x] Deploy Traefik ingress controller
- [x] Deploy Pi-hole (DNS + DHCP on blueberrypi)
- [x] Configure static IPs for cluster nodes via Ansible (jellypi, cherrypi, blueberrypi)
- [ ] Set up NFS shared storage from jellypi's 1TB SSD — local-path PVCs are node-bound and painful to manage
- [x] Set up VPN — Headscale on argonath, Tailscale on jellypi + cherrypi
- [x] Set up ProtonVPN exit node on jellypi — see ADR-009 and runbooks/exit-node-setup.md
- [ ] Deploy ARR stack (Sonarr, Radarr, Prowlarr)
- [ ] Deploy qBittorrent behind Gluetun (VPN kill switch)
- [ ] Set up fail2ban on SSH (argonath is internet-exposed)
- [x] Deploy cloudflared tunnel — Traefik exposed via Cloudflare Tunnel, routing at Ingress level (see ADR-010)
- [ ] Deploy Authelia — OIDC provider + Traefik forward-auth, replaces dashboard basic-auth as first integration (see ADR-011)

## Known Issues / Tech Debt

- **k3s-ansible 1.2.0 breaks vault-encrypted `token`**: PR #509 in k3s-ansible replaced Jinja2 templates with `to_nice_yaml` for writing `/etc/rancher/k3s/config.yaml`. This causes `AnsibleVaultEncryptedUnicode` objects to be serialized as `!vault |` ciphertext instead of being decrypted, so k3s uses the raw ciphertext as its cluster secret. Pinned to `1.1.1` in `requirements.yml` as workaround. Upstream issue + fix pending — see `docs/runbooks/ansible-setup.md`.

## Conventions

- All manifests live under `k8s/`
- Document decisions and migrations in `docs/`
