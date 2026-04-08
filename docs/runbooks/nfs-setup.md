# NFS Setup

jellypi exports its LUKS-encrypted SSD (`/media/sandisk`) over NFS to cluster nodes via Tailscale MagicDNS. Exports are defined per-host in `host_vars` and clients discover them dynamically — no per-client mount configuration needed.

## How it works

```
host_vars/jellypi → nfs_exports → nfs_server role → /etc/exports
                                → nfs_client role (on all nfs_clients) → fstab + mount
```

Each export entry is self-describing: path, allowed network, mount options, and access group are all co-located. The client role iterates over `groups['nfs_servers']` and reads each server's `nfs_exports` via `hostvars` — adding a new server or export requires no changes on the client side.

NFS mounts use MagicDNS hostnames (`<host>.ts.scrimreaper.dev`) so Tailscale IPs are never hardcoded.

## Adding a new NFS server

### 1. Add to inventory

```yaml
# inventory.yml
nfs_servers:
  hosts:
    newhost:
```

### 2. Define exports in host_vars

```yaml
# host_vars/newhost/plain.yaml
nfs_exports:
  - path: /path/to/export
    exposure: "{{ scale_netmask.v4 }}"
    options: "rw,sync,no_subtree_check,no_root_squash"
    local_mount: /mnt/nfs/something
    mount_opts: "rw,hard,intr,timeo=600,retrans=2,_netdev"
    group: media
    gid: 1001
```

Use `scale_netmask.v4` (`100.64.0.0/10`) as the exposure to restrict access to the Tailscale network.

### 3. Run the playbook

```bash
ansible-playbook pb_storage.yaml
```

All existing `nfs_clients` will automatically pick up and mount the new server's exports on the next run.

## Adding a new NFS client

### 1. Add to inventory

```yaml
# inventory.yml
nfs_clients:
  hosts:
    newhost:
```

### 2. Run the playbook

```bash
ansible-playbook pb_storage.yaml
```

The role discovers all `nfs_servers` and their exports dynamically — no further configuration needed.

## Adding a new export to an existing server

Add a new entry to `nfs_exports` in the server's `host_vars`:

```yaml
nfs_exports:
  - path: /media/sandisk        # existing
    ...
  - path: /path/to/new/export   # new
    exposure: "{{ scale_netmask.v4 }}"
    options: "rw,sync,no_subtree_check,no_root_squash"
    local_mount: /mnt/nfs/newexport
    mount_opts: "rw,hard,intr,timeo=600,retrans=2,_netdev"
    group: media
    gid: 1001
```

Then run `ansible-playbook pb_storage.yaml`. All clients mount it automatically.

## Removing an export

1. Remove the entry from `nfs_exports` in the server's `host_vars` and run `pb_storage.yaml` — `/etc/exports` is rewritten automatically.
2. On each client, unmount and remove from fstab manually (the role won't clean up old mounts):
   ```bash
   sudo umount /mnt/nfs/<export>
   sudo sed -i '/\/mnt\/nfs\/<export>/d' /etc/fstab
   sudo rmdir /mnt/nfs/<export>
   ```
3. Reset permissions on the export path on the server if needed:
   ```bash
   sudo chgrp root /path/to/export
   sudo chmod 0755 /path/to/export
   ```

## Notes

- **Existing files**: the `nfs_server` role sets `root:media 2775` (setgid) on export paths so new files inherit the group. Existing files need a one-time fix:
  ```bash
  chgrp -R media /path/to/export
  chmod -R g+rw /path/to/export
  ```
- **ARR stack / containers**: set `PGID=<gid>` in the container spec to match the export's `gid` field.
- **GID consistency**: NFS maps by GID number. The `nfs_client` role creates the group with the correct GID automatically — but if you add a new group, make sure the GID doesn't clash with existing system groups on the client.
