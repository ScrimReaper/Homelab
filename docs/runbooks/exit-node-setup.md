# Exit Node Setup (ProtonVPN via Tailscale)

`jellypi` acts as a Tailscale exit node, routing internet-bound traffic from tailnet devices through a ProtonVPN WireGuard tunnel. This allows all devices to benefit from ProtonVPN without running it locally — which conflicts with Tailscale on the same device.

See [ADR-009](../adr/009-k3s-tailscale-exit-node.md) for the decision rationale.

## How it works

```
tailnet device → tailscale0 (jellypi) → protonvpn (WireGuard) → ProtonVPN server → internet
```

Key routing rules on jellypi (set via wg-quick PostUp):
- `ip rule add iif tailscale0 table 200` — only traffic arriving from `tailscale0` uses table 200 (ProtonVPN). jellypi's own traffic is unaffected.
- `iptables MASQUERADE` — rewrites source IPs of exit node traffic to jellypi's ProtonVPN address before forwarding
- `iptables -I FORWARD -i tailscale0 ! -o protonvpn -j REJECT` — kill switch: if the ProtonVPN tunnel drops, exit node traffic is rejected rather than leaking through `eth0`

## Initial Deployment

### 1. Obtain ProtonVPN WireGuard config

Download from the ProtonVPN portal (Linux → WireGuard). Disable NAT options, enable VPN Accelerator only.

Vault-encrypt the credentials and store them in `group_vars/exit_node/vault.yaml`:
- `proton_private_key`
- `proton_public_key`
- `proton_address`
- `proton_endpoint`

### 2. Run the playbook

```bash
ansible-playbook pb_tailscale.yaml
```

This installs WireGuard, deploys the config, brings up the tunnel, advertises the exit node, and sets it on all other tailscale hosts.

### 3. Approve exit node routes in Headscale

The exit node routes (`0.0.0.0/0`, `::/0`) are managed via `group_vars/headscale/plain.yaml` (`headscale_exit_nodes`). If adding a new exit node, get its node ID first:

```bash
ssh argonath 'sudo headscale nodes list'
```

Then add it to `headscale_exit_nodes` and run:

```bash
ansible-playbook pb_headscale.yaml
```

Or approve manually on argonath:
```bash
sudo headscale nodes approve-routes --identifier <id> --routes 0.0.0.0/0,::/0
```

### 4. Verify

On any non-exit-node tailscale host:
```bash
curl ifconfig.me  # should return a ProtonVPN IP
```

Check the tunnel status on jellypi:
```bash
sudo wg show protonvpn  # look for a recent "latest handshake"
```

## Rotating ProtonVPN Credentials

ProtonVPN WireGuard configs expire periodically. To rotate:

1. Download a fresh config from the ProtonVPN portal
2. Update the vault-encrypted values in `group_vars/exit_node/vault.yaml`
3. Re-run the playbook — the template task will detect the change and trigger a tunnel restart via the handler

## Troubleshooting

**Tunnel is down but service shows `active (exited)`**
wg-quick is `Type=oneshot` — systemd keeps it as `active (exited)` even after the interface is torn down (e.g. after `wg-quick down`). The playbook detects this by checking `/sys/class/net/protonvpn` and restarts if missing. To fix manually:
```bash
sudo systemctl restart wg-quick@protonvpn
```

**LAN hosts unreachable from a client using the exit node**
By default, Tailscale routes all traffic including LAN through the exit node. The playbook sets `--exit-node-allow-lan-access` to bypass this. If LAN access is still broken, verify the flag is set:
```bash
tailscale status --json | grep exitNodeAllowLANAccess
```

**Traffic not going through ProtonVPN (`curl ifconfig.me` shows home IP)**
Check in order:
1. Is the tunnel up? `sudo wg show protonvpn` — look for a recent handshake
2. Are the routing rules in place? `ip rule show` — should have a rule for `iif tailscale0 lookup 200` at priority 6000
3. Are the Headscale exit node routes approved? `sudo headscale nodes list-routes` on argonath

## Gotchas

- **`ip rule` without `iif tailscale0` locks you out of LAN** — the original rule `ip rule add table 200 priority 6000` (without `iif`) routes ALL traffic through ProtonVPN, including jellypi's own reply packets to LAN SSH connections. Always scope the rule to `iif tailscale0` so only forwarded exit-node traffic is affected.

- **`state: started` doesn't bring up a torn-down oneshot service** — after `wg-quick down`, systemd still considers the service `active (exited)`. Ansible's `state: started` sees this as already running and does nothing. The role works around this with an interface existence check.

- **Headscale route approval is not automatic** — advertising `--advertise-exit-node` from the client side is not enough. Headscale must explicitly approve the `0.0.0.0/0` and `::/0` routes.

- **Play order matters** — the ProtonVPN role must run after Tailscale is installed. The kill switch PostUp rule references `tailscale0`, which doesn't exist until Tailscale is up.

- **`--exit-node-allow-lan-access` is required for LAN reachability** — without it, client nodes using the exit node lose access to `192.168.0.0/24` because responses are routed through the exit node instead of directly over eth0.
