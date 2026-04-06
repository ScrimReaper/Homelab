# Scale Network Setup (Headscale + Tailscale)

This runbook covers deploying and managing the VPN mesh — Headscale on `argonath` as the control plane, Tailscale clients on all other nodes.

See [ADR-008](../adr/008-vpn-remote-access.md) for the decision rationale.

## Prerequisites

- `argonath` provisioned and reachable over SSH
- DNS A record: `headscale.scrimreaper.dev → 89.127.233.64`
- Port 80, 443, 3478/udp, 41641/udp open on argonath (via UFW)
- Ansible vault password available

## Initial Deployment

### 1. Deploy Headscale

```bash
ANSIBLE_ALLOW_BROKEN_CONDITIONALS=true ansible-playbook pb_main.yaml -l argonath
```

> `ANSIBLE_ALLOW_BROKEN_CONDITIONALS=true` is required due to a bug in `kazauwa.headscale` where `when: headscale_config` uses dict truthiness. Fix is pending upstream — see `tasks/configure.yml:3`.

Verify headscale is running and listening on 443:

```bash
ssh argonath 'sudo ss -tlnp | grep headscale'
sudo journalctl -u headscale -n 50
```

### 2. Create a Pre-Auth Key

```bash
ssh argonath 'sudo headscale preauthkeys create --user <UserID> --reusable'
```

UserID can be found by:

```bash
headscale users list
```

Encrypt the key and store it in `group_vars/scale_network/vault.yaml`:

### 3. Deploy Tailscale Clients

```bash
ANSIBLE_ALLOW_BROKEN_CONDITIONALS=true ansible-playbook pb_main.yaml -l jellypi,cherrypi
```

### 4. Verify

```bash
ssh argonath 'sudo headscale nodes list'
```

Both `jellypi` and `cherrypi` should appear under user `mo`.

## Adding a New Node

1. Add the host to the `tailscale` group in `inventory.yml`
2. Re-run the tailscale playbook against the new host:
   ```bash
   ansible-playbook pb_tailscale.yaml -l <new-host>
   ```
3. The existing reusable auth key will be used automatically.

## ACL Policy

The ACL file lives at `ansible/files/headscale_acl.hujson`. Currently allows all nodes to reach all other nodes. Edit and re-run the headscale playbook to apply changes.

## Known Issues

- `kazauwa.headscale` role uses `when: headscale_config` (dict truthiness) which fails on Ansible 2.18+. Workaround: `ANSIBLE_ALLOW_BROKEN_CONDITIONALS=true`. Upstream fix: change to `when: headscale_config | length > 0` in `tasks/configure.yml`.
