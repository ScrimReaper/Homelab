# Ansible Setup

## Prerequisites

- Python 3 installed on your machine
- SSH access to the target hosts
- Target nodes flashed with Raspberry Pi OS Lite 64-bit (Debian Trixie)

## Setup

```bash
cd ansible/

# create venv, install ansible and collections
./setup-ansible-environment.sh

# activate venv in your shell (must be done manually — script activation doesn't carry over)
source venv/bin/activate
```

## Provisioning a new node

### Step 1 — Bootstrap

Run once on a fresh host. Connects as `admin` (the default installation user) and sets up the `ansible` user with SSH key access and passwordless sudo.

```bash
ansible-playbook pb_boostrap.yaml --limit <hostname> --ask-pass --ask-become-pass
```

After this, the `ansible` user is in place and no password prompt is needed going forward.

### Step 2 — Full provisioning

`pb_main.yaml` is the main entry point — it runs common, crypto, and k3s in order.

```bash
ansible-playbook pb_main.yaml --limit <hostname>
```

> **Note:** The common role skips UFW on k3s nodes. The UFW block in `roles/common/tasks/05_hardening.yaml` is gated with `when: inventory_hostname not in groups['k3s_cluster']`, so any host in the `k3s_cluster` group (or its children) will not have UFW installed or enabled.

## k3s cluster

The k3s cluster is provisioned via the `k3s.orchestration` collection (k3s-ansible). The cluster token is vault-encrypted in `inventory.yml`.

To generate a new token:

```bash
ansible-vault encrypt_string "$(openssl rand -base64 64)" --name 'token'
```

### Known issue: vault-encrypted token broken in k3s-ansible 1.2.0

k3s-ansible 1.2.0 (PR #509) replaced Jinja2 templates with `to_nice_yaml` to write `/etc/rancher/k3s/config.yaml`. Ansible's `to_nice_yaml` serializes `AnsibleVaultEncryptedUnicode` objects back as `!vault |` ciphertext rather than decrypting them. k3s then uses the raw ciphertext string as its cluster secret, which breaks the cluster when the config is regenerated (e.g. on version upgrade).

**Workaround:** `requirements.yml` is pinned to `version: 1.1.1`. Do not upgrade to `main`/`1.2.0` until the upstream fix lands.

**Fix direction:** In `k3s_server/tasks/main.yml`, the token must be coerced to a plain string before being passed to `combine()`, e.g.:
```yaml
token_str: "{{ token | string }}"
k3s_server_config: "{{ k3s_server_config | combine({'token': token_str}) }}"
```

Upstream issue: https://github.com/k3s-io/k3s-ansible/issues (pending)

## LUKS encrypted disk

The `pb_crypto.yaml` playbook (included in `pb_main.yaml`) opens and mounts the LUKS-encrypted disk on hosts in the `crypto` group. The passphrase is vault-encrypted in `host_vars/`.

Long-term plan: replace the vault passphrase with Tang/NBDE for network-bound disk encryption once a VPN is set up between nodes.
