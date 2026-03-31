# ADR-007 — Move Pi-hole to Dedicated Hardware Outside the Cluster

**Date:** 2026-03-31
**Status:** Decided

## Context

Pi-hole currently runs inside the k3s cluster on cherrypi with `hostNetwork: true` (see ADR-006). This was already a workaround — `hostNetwork` bypasses cluster networking to handle DHCP broadcasts, pinning Pi-hole to a specific node and introducing tight coupling between cluster scheduling and physical network infrastructure.

The planned introduction of a Tailscale/Headscale overlay network across cluster nodes adds further complexity: Pi-hole as a cluster workload would need to interoperate correctly with Tailscale's DNS resolver, routing, and interface management. Running DNS inside a network that itself depends on DNS creates a fragile bootstrap dependency.

## Decision

Move Pi-hole to **blueberrypi** (Raspberry Pi Zero W), a dedicated device managed by Ansible but **not part of the k3s cluster**. Pi-hole runs directly on the host OS, not as a Kubernetes workload.

### Static IPs for hosts on the home network

Any host that relies on Pi-hole for DHCP must have a static IP configured before Pi-hole is migrated or taken down for maintenance. Without this, a Pi-hole outage means those hosts cannot renew their lease, lose network access, and become unreachable via SSH — recovering requires enabling the router's built-in DHCP, which takes 5–10 minutes and is disruptive.

Hosts that need a static IP are grouped under `static_ip` in the Ansible inventory. A dedicated play in `pb_common.yaml` targets this group and configures static addresses via nmcli (for NetworkManager hosts), running after the common role. This is intentionally a separate play rather than a role task so it can be scoped to only the relevant hosts without affecting the rest of the fleet.

## Consequences

**Simplifications:**
- DNS and DHCP are decoupled from the cluster lifecycle — Pi-hole keeps working if k3s is down, nodes are being rebooted, or Tailscale is being reconfigured
- No more `hostNetwork: true` workaround or node pinning for DHCP
- Removes a stateful workload from the cluster, which also unblocks the NFS storage migration (one less PVC to worry about)
- Cluster nodes can point to a stable, external DNS IP regardless of what's happening inside the cluster

**Trade-offs:**
- Pi-hole is no longer managed declaratively via Flux/GitOps — configuration is managed via Ansible instead
- blueberrypi (ARMv6, 512MB RAM) is low-powered, but Pi-hole's resource requirements are minimal
- One more host to maintain in Ansible inventory

## Supersedes

The Pi-hole sections of ADR-006 are superseded by this decision. The rest of ADR-006 (MetalLB, Traefik, NFS storage) remains valid.
