# Gotchas

A running list of non-obvious issues and their fixes.

---

## Flux: kustomize-controller can't resolve in-cluster DNS

**Symptom:** `dial tcp: lookup source-controller.flux-system.svc.cluster.local: i/o timeout`

**Cause:** The kustomize-controller pod landed on the worker node (cherrypi) and Flannel's overlay tunnel is degraded — usually after a node IP change or reboot.

**Fix:** Restart the k3s agent on cherrypi:
```bash
ssh cherrypi sudo systemctl restart k3s-agent
```

---

## UFW blocks k3s inter-node traffic

**Symptom:** Pods on the worker node can't reach services on the control plane (DNS timeouts, connection refused).

**Cause:** UFW drops Flannel VXLAN (UDP 8472) and other k3s inter-node traffic.

**Fix:** UFW is intentionally disabled on k3s nodes via the Ansible `common` role (`when: inventory_hostname not in groups['k3s_cluster']`). If UFW is accidentally enabled on a k3s node, disable it:
```bash
sudo ufw disable
```

---

## Node IP change breaks Flannel

**Symptom:** After a node's LAN IP changes, inter-pod communication breaks. Pods on that node can't reach services on other nodes.

**Fix:** Restart the k3s agent on the affected node to re-register with the new IP:
```bash
ssh <node> sudo systemctl restart k3s-agent
```

Also update `ansible/inventory.yml` and `ssh/config.template` with the new IP.

---

## Pi-hole DHCP requires NET_ADMIN capability

**Symptom:** `CRIT: Error in dnsmasq configuration: process is missing required capability NET_ADMIN`

**Cause:** DHCP requires the `NET_ADMIN` Linux capability to manage network interfaces. Containers don't get it by default.

**Fix:** Add to Pi-hole HelmRelease values:
```yaml
capabilities:
  add:
    - NET_ADMIN
```

---

## Pi-hole DHCP doesn't work behind MetalLB

**Symptom:** Pi-hole DNS works fine but DHCP clients don't get IPs after disabling router DHCP.

**Cause:** DHCP clients broadcast to `255.255.255.255` before they have an IP — they never reach a MetalLB virtual IP. MetalLB only handles unicast traffic.

**Fix:** Run Pi-hole with `hostNetwork: true` so it binds directly to the node's physical NIC. Pin it to a specific node with `nodeSelector` so the IP stays stable:
```yaml
hostNetwork: true
nodeSelector:
  kubernetes.io/hostname: cherrypi
```

---

## Pi-hole v6 ignores dnsmasq customSettings for DHCP

**Symptom:** DHCP range set via `dnsmasq.customSettings` is not applied — Pi-hole dashboard shows empty DHCP config.

**Cause:** Pi-hole v6 manages DHCP through FTL (its own DNS/DHCP engine) rather than raw dnsmasq config. The `customSettings` approach was for older versions.

**Fix:** Use FTL environment variables via `extraEnvVars`:
```yaml
extraEnvVars:
  FTLCONF_dhcp_active: "true"
  FTLCONF_dhcp_start: "192.168.0.2"
  FTLCONF_dhcp_end: "192.168.0.150"
  FTLCONF_dhcp_router: "192.168.0.1"
```

---

## local-path PVCs are node-bound

**Symptom:** Pod stuck in `Pending` with `1 node(s) didn't match PersistentVolume's node affinity`.

**Cause:** k3s's `local-path` provisioner creates PVs on the node where the PVC was first bound. If the pod is rescheduled to a different node (or `nodeSelector` is changed), the PVC can't follow.

**Fix:** Delete the PVC (and PV if stuck), then recreate:
```bash
kubectl delete pvc <name> -n <namespace>
# If PV is stuck, patch out finalizers:
kubectl patch pv <pv-name> -p '{"metadata":{"finalizers":null}}'
kubectl delete pv <pv-name>
# Recreate manually or force Flux reconcile
```

**Long-term fix:** Migrate to NFS-backed storage so PVCs are node-independent.

---

## Flux bootstrap times out waiting for Kustomization

**Symptom:** `bootstrap failed with 1 health check failure(s): kustomization 'flux-system/flux-system' not ready: 'Reconciliation in progress'`

**Cause:** The bootstrap command's 5-minute timeout was hit while the kustomization was still reconciling — not a real failure.

**Fix:** Check the actual state after bootstrap:
```bash
flux get kustomizations
```
If `READY: True`, bootstrap succeeded and the timeout message can be ignored.

---

## Pi-hole v6 ignores toml values for DHCP/DNS config after first start

**Symptom:** DHCP range, gateway, upstream DNS servers, or other settings in `pihole.toml` are reset to defaults on startup. Logs show `Resetting X to default (not forced anymore)`.

**Cause:** Pi-hole v6 has two sources of truth — `pihole.toml` and its internal database (`pihole-FTL.db`). Once the database is initialized (on first start), it takes precedence over the toml for most settings.

**Fix:** Configure these settings via the web UI (Settings → DNS / DHCP) — it writes directly to the database. The toml is still respected for settings that haven't been touched via the UI.
