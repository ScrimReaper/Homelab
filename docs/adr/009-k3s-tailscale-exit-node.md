# ADR-009 — k3s over Tailscale and Exit Node Strategy

**Date:** 2026-04-07
**Status:** Decided

## Context

ADR-008 established Headscale/Tailscale as the VPN overlay and noted that k3s would need to be reinstalled on top of it. Two follow-on decisions are captured here.

**k3s cluster networking**: k3s was initially installed with nodes communicating over the home LAN. Following a zero-trust approach — where security should not depend on the integrity of the underlying network — all cluster traffic (pod-to-pod overlay, kubelet ↔ API server, remote kubectl) should be encrypted end-to-end regardless of what network the nodes are on.

**Internet privacy**: ProtonVPN is used for internet privacy on personal devices, but ProtonVPN and Tailscale cannot run simultaneously on the same device — both manage the system routing table and DNS resolver, causing conflicts. Running one means losing the other.

## Decisions

### 1. k3s over Tailscale

Run the entire k3s cluster over the Tailscale network:

- **`--flannel-iface tailscale0`**: Flannel uses the Tailscale interface for pod overlay networking. Pod-to-pod traffic between nodes is WireGuard-encrypted by Tailscale before it leaves the host.
- **`--node-ip <tailscale-ip>`**: Each node registers in the cluster with its Tailscale IP as `InternalIP`, ensuring apiserver ↔ kubelet traffic (`kubectl exec`, `kubectl logs`, port-forwarding) also routes through the tailnet.
- **`api_endpoint`**: Points to the server's MagicDNS hostname (`jellypi.ts.scrimreaper.dev`), derived from the Headscale config. Remote kubectl works from any tailnet device.
- **`--tls-san`**: API server certificate includes the MagicDNS hostname so TLS is valid for remote connections.

#### Why not Flannel `wireguard-native` backend?

Flannel's `wireguard-native` backend adds a WireGuard encryption layer to the pod overlay. With `--flannel-iface tailscale0`, Flannel traffic already travels inside an encrypted Tailscale (WireGuard) tunnel — a second WireGuard layer would add overhead with no security benefit.

#### Note on `--node-ip`

For the current two-node setup (jellypi + cherrypi on the same LAN), the ISP cannot see intra-LAN traffic, so `--node-ip` is not strictly required by the threat model. It is kept for consistency (the cluster only knows Tailscale IPs) and to future-proof adding nodes off the home LAN without config changes.

### 2. Exit Node with ProtonVPN

Designate **jellypi** as a Tailscale exit node running a ProtonVPN WireGuard tunnel. Internet-bound traffic from tailnet devices that select jellypi as their exit node is forwarded through ProtonVPN.

This resolves the ProtonVPN/Tailscale conflict: instead of running both on each device, only jellypi runs ProtonVPN. Personal devices connect to the tailnet, optionally select jellypi as exit node, and get ProtonVPN protection with no local VPN client required.

#### Why jellypi?

- Always-on (k3s control plane node)
- On the home LAN — low latency for the initial hop
- argonath is explicitly not intended for end-user traffic routing (see ADR-008)

## Consequences

- All k3s cluster traffic is WireGuard-encrypted via Tailscale — the ISP sees only encrypted UDP to Tailscale peers
- Remote kubectl works from any tailnet device without additional tunnelling
- Personal devices get ProtonVPN protection by selecting jellypi as Tailscale exit node — no local ProtonVPN client needed, no Tailscale/ProtonVPN conflict
- If jellypi is unavailable, devices using it as exit node lose internet access — acceptable trade-off for a homelab
- ProtonVPN WireGuard config must be provisioned and maintained on jellypi
