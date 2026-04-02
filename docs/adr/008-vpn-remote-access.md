# ADR-007 — VPN and Remote Access Strategy

**Date:** 2026-04-02
**Status:** Decided

## Context

The homelab runs on a private LAN with no public IPs assigned to individual nodes. Accessing the cluster remotely (SSH, kubectl, internal services) would otherwise require either:

- Port forwarding on the home router — brittle, exposes specific ports publicly, breaks when the public IP changes (no static IP)
- A jumphost with manual SSH tunnelling — cumbersome and not scalable

A VPN overlay solves this cleanly: all devices appear on a shared virtual network regardless of their physical location, enabling direct SSH and service access without exposing anything to the public internet.

## Decision

Deploy **Headscale** (self-hosted Tailscale control plane) on `argonath`, a VPS hosted at 1984 Hosting, as the coordination server for a Tailscale-based mesh VPN.

### Why Tailscale / Headscale

- **Tailscale** provides a WireGuard-based mesh VPN with automatic NAT traversal (DERP relay fallback), key management, and ACLs — without requiring manual WireGuard peer configuration
- **Headscale** replaces Tailscale's SaaS control plane with a self-hosted equivalent, keeping the convenience of the Tailscale client while retaining full control over the coordination server and avoiding dependency on Tailscale's infrastructure
- Alternatives considered:
  - **Plain WireGuard**: requires manual peer management and static IPs — operationally heavier
  - **Tailscale SaaS**: simpler setup but ties the network to a third-party control plane; free tier limits apply

### Role of argonath

`argonath` (1 vCPU, 2GB RAM, 50GB SSD) runs the Headscale control plane only. It is **not** intended as an application server or exit node for end-user traffic. Its role is:

1. Serve as the Headscale coordination server (reachable on the public internet)
2. Act as a DERP relay fallback for peers that cannot establish direct connections

Direct peer-to-peer WireGuard tunnels are established between devices wherever NAT traversal succeeds — argonath is not in the data path for those connections.

## Application Exposure (Separate Concern)

Exposing homelab applications to friends and family is explicitly **out of scope** for this VPN setup. The VPN is for operator access only (SSH, kubectl, internal dashboards). Public-facing application exposure will be handled via an outbound tunnel — candidates are:

- **Cloudflare Tunnel** (cloudflared) — already referenced in ADR-006 for Traefik
- **Pangolin** — self-hosted alternative

This separation keeps the VPN network small and access-controlled, while application exposure can be managed independently with its own authentication and routing layer.

## Consequences

- All homelab nodes (jellypi, cherrypi) and personal devices enroll as Tailscale peers via the Headscale control plane on argonath
- SSH and kubectl access from anywhere requires only a Tailscale connection — no port forwarding or jumphost needed
- argonath must remain reachable on the public internet; UFW allows SSH and the Headscale/DERP ports
- LUKS Tang/NBDE unlock (deferred in ADR-006) becomes feasible once the VPN is stable — Tang can be reached over the Tailscale network
- Application exposure strategy (Cloudflare Tunnel / Pangolin) to be decided in a follow-up ADR
- K3s cluster needs to be reinstalled ontop of the VPN once configured
