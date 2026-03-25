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

## Bootstrap a new node

The bootstrap playbook connects as `root` (first run on a fresh OS install) and sets up the `ansible` user with SSH key access and passwordless sudo.

```bash
ansible-playbook pb_boostrap.yaml --ask-pass
```

After the bootstrap the `ansible` user is in place and subsequent playbooks run without a password prompt.
