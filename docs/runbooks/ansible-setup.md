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

> **Warning:** The common role includes UFW hardening which conflicts with k3s networking (k3s requires open inter-node ports that UFW blocks). Do not run `pb_common.yaml` independently on k3s nodes until this is refactored.

## k3s cluster

The k3s cluster is provisioned via the `k3s.orchestration` collection (k3s-ansible). The cluster token is vault-encrypted in `inventory.yml`.

To generate a new token:

```bash
ansible-vault encrypt_string "$(openssl rand -base64 64)" --name 'token'
```

## LUKS encrypted disk

The `pb_crypto.yaml` playbook (included in `pb_main.yaml`) opens and mounts the LUKS-encrypted disk on hosts in the `crypto` group. The passphrase is vault-encrypted in `host_vars/`.

Long-term plan: replace the vault passphrase with Tang/NBDE for network-bound disk encryption once a VPN is set up between nodes.
