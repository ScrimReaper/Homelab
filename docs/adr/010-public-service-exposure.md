# ADR-010 — Public Service Exposure via Cloudflare Tunnel

**Date:** 2026-04-16
**Status:** Decided

## Context

This ADR fulfills the follow-up committed to in [ADR-008](008-vpn-remote-access.md), which explicitly deferred public application exposure to a separate decision. ADR-008 identified Cloudflare Tunnel and Pangolin as the two candidates and noted that the VPN is for operator access only — public-facing services require a separate mechanism.

Services running in the k3s cluster are only reachable within the Tailscale network. Exposing them publicly requires a mechanism to accept inbound internet traffic without opening ports on the home router or assigning public IPs to cluster nodes.

Two options were evaluated:

**Pangolin** — a self-hosted tunneling solution (WireGuard-based). Runs a server component on a public VPS (argonath) and a client (Newt) in the cluster. Traffic flows: Internet → Pangolin on argonath → WireGuard tunnel → Newt → cluster services.

Problems with this approach:
- argonath already runs Headscale (1 vCPU, 2GB RAM) — adding Pangolin + Gerbil + a second Traefik instance is resource-constrained and introduces port conflicts on 80/443
- More moving parts to operate and keep updated

**Cloudflare Tunnel (cloudflared)** — runs a lightweight connector in the cluster that establishes outbound connections to Cloudflare's edge. No inbound ports needed on argonath or the home router.

## Decision

Use Cloudflare Tunnel as an interim solution. Deploy cloudflared as a Deployment in the cluster (2 replicas for HA). All traffic is forwarded to Traefik (`traefik.traefik.svc.cluster.local:80`), which routes it via existing Ingress resources. Traefik stays `ClusterIP` — cloudflared reaches it cluster-internally, no LoadBalancer service needed.

Routing is intentionally kept at the **Ingress level**, not hardcoded into the tunnel config. This means the tunnel is a dumb forwarder: it delivers traffic to Traefik and Traefik owns all routing decisions. The practical consequence is that switching tunnel providers (e.g. to Pangolin) requires replacing only the cloudflared Deployment — no changes to any Ingress resources or service configuration. Full self-hosting via Pangolin is the long-term goal; Cloudflare Tunnel is chosen now for operational simplicity while the cluster matures.

Authentication uses a tunnel token stored as a SOPS-encrypted Secret. Hostname routing (which domain maps to which service) is managed in the Cloudflare dashboard — not declaratively in git. This is a deliberate trade-off: the routing config is simple enough (one rule per service, all via Traefik) that dashboard management is not burdensome. DNS management via Terraform/OpenTofu (noted in ADR-004) remains an option if the number of managed hostnames grows.

## Consequences

- Services are publicly reachable without touching argonath or the home router
- TLS is terminated at Cloudflare's edge — cluster-internal traffic is plain HTTP, which is acceptable given it travels over the Tailscale (WireGuard) network
- Adding a new public service = add an Ingress resource + add a public hostname entry in the Cloudflare dashboard
- Hostname routing config lives in the Cloudflare dashboard, not in git — this is the one non-declarative part of the setup and should be noted when onboarding
- Switching to Pangolin in the future requires only replacing the cloudflared Deployment — Ingress resources are unaffected
- Domain must be on Cloudflare DNS (required for tunnel integration)
