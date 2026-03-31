# ADR-006 — Bare-Metal Networking and Storage Strategy

**Date:** 2026-03-29
**Status:** Decided (storage partially pending)

> **Note:** The Pi-hole sections of this ADR have been superseded by [ADR-007](007-pihole-dedicated-hardware.md). Running Pi-hole inside the cluster proved operationally painful — DHCP broadcasts, hostNetwork coupling, and Tailscale DNS complexity made it impractical. Pi-hole has been moved to dedicated hardware (blueberrypi) outside the cluster.

## Context

Running Kubernetes on bare metal means no cloud load balancer and no networked storage out of the box. We need solutions for both.

## Networking Decision

### MetalLB (Layer 2 mode)

**MetalLB** provides LoadBalancer-type services on bare metal by responding to ARP requests for a pool of reserved LAN IPs (`192.168.0.200-192.168.0.254`). The router's DHCP range is capped at `.150` to avoid conflicts.

Installed via kustomize from the upstream manifest (`metallb-native`).

### Traefik (Ingress Controller)

**Traefik** is deployed via Helm as the cluster ingress controller. Currently `ClusterIP` (internal only) — will be switched to `LoadBalancer` when services are exposed externally via Cloudflare Tunnel.

Dashboard is enabled with BasicAuth (credentials in a SOPS-encrypted Secret).

### Pi-hole (DNS + DHCP)

Pi-hole runs on **cherrypi** with `hostNetwork: true`. This is required for DHCP:

- **DNS** works fine via MetalLB (unicast to a virtual IP) — but DHCP clients broadcast to `255.255.255.255` before they have an IP, so they never reach a virtual MetalLB IP.
- `hostNetwork: true` binds Pi-hole directly to cherrypi's physical NIC, making it reachable for DHCP broadcasts.
- A `nodeSelector` pins the pod to cherrypi so the DNS IP (`192.168.0.47`) stays stable.

Pi-hole handles both DNS (ad-blocking, upstream: Cloudflare `1.1.1.1` + Google `8.8.8.8`) and DHCP (range `192.168.0.2-192.168.0.150`, static leases for all known hosts).

## Storage Decision

### Current: local-path (k3s default)

The k3s built-in `local-path` provisioner is used for Pi-hole's PVC. **This is a known pain point** — local-path PVCs are bound to the node they were created on, so pods cannot be rescheduled to a different node without manually deleting and recreating the PVC.

### Planned: NFS from jellypi

jellypi has a 1TB LUKS-encrypted SSD at `/mnt/media`. The plan is to expose a share via NFS and use it as a cluster-wide storage backend. This will allow PVCs to be accessed from any node, making pod scheduling and migrations trivial.

Once NFS is set up:
- Pi-hole's PVC will be migrated
- All future stateful workloads (Jellyfin, Immich, etc.) will use NFS-backed storage

## Consequences

- DHCP and DNS are now managed declaratively in Git via Pi-hole's HelmRelease values
- `hostNetwork: true` means Pi-hole bypasses the cluster network — port conflicts on the host are possible if other workloads use ports 53, 67, or 80
- local-path storage requires manual intervention when moving pods between nodes — to be resolved when NFS is set up
