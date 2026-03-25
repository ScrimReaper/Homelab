# Ansible Setup

## Prerequisites

- Python 3 installed on your machine
- SSH access to the target hosts

## Setup

```bash
cd ansible/

# create and activate venv
python -m venv venv
source venv/bin/activate

# install ansible
pip install -r requirements.txt

# install ansible collections
ansible-galaxy collection install -r requirements.yml
```

## Bootstrap a new node

The bootstrap playbook connects as `root` (first run on a fresh OS install) and sets up the `ansible` user with SSH key access and passwordless sudo.

```bash
ansible-playbook pb_boostrap.yaml --ask-pass
```

After the bootstrap the `ansible` user is in place and subsequent playbooks run without a password prompt.
