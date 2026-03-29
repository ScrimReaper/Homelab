# Flux GitOps Setup

## Overview

The cluster uses FluxCD to reconcile Kubernetes state from this git repository. Flux is bootstrapped via the CLI and self-manages from that point on.

## Bootstrap

Flux was bootstrapped against the GitHub repo with:

```bash
flux bootstrap github \
  --token-auth \
  --owner=ScrimReaper \
  --repository=Homelab \
  --branch=main \
  --path=k8s \
  --personal
```

This created `k8s/flux-system/` with Flux's own component manifests and a `Kustomization` that watches `./k8s`.

## Repository Structure

```
k8s/
├── kustomization.yaml        # Root — includes flux-system/ and flux/
├── flux-system/              # Managed by Flux bootstrap, do not edit
├── flux/
│   ├── kustomization.yaml
│   ├── infrastructure.yaml   # infra-controllers + infra-configs Kustomizations
│   └── apps.yaml             # apps Kustomization
├── infrastructure/
│   ├── controllers/          # Cluster controllers (MetalLB, Traefik, etc.)
│   └── configs/              # CRD-based config (IPAddressPool, etc.)
└── apps/                     # Application HelmReleases (Pi-hole, Jellyfin, etc.)
```

The `infra-configs` Kustomization has `dependsOn: infra-controllers` — Flux will not apply CRD-based config until the controllers are healthy.

The `apps` Kustomization has `dependsOn: infra-configs` — apps are not reconciled until infrastructure is ready.

## SOPS Secret Encryption

Secrets in `k8s/` are encrypted with SOPS + age. The age private key is stored as a cluster secret:

```bash
cat age.agekey | kubectl create secret generic sops-age \
  --namespace=flux-system \
  --from-file=age.agekey=/dev/stdin
```

The public key is at `pubkey.age` in the repo root. The `.sops.yaml` rules file encrypts only `data` and `stringData` fields in any `k8s/**/*.yaml` file.

To encrypt a new secret:
```bash
sops -e -i k8s/path/to/secret.yaml
```

To edit an encrypted secret:
```bash
sops k8s/path/to/secret.yaml
```

**Never commit unencrypted secrets.** The age private key (`age.agekey`) is in `.gitignore`.

## Common Commands

```bash
# Check all Kustomizations
flux get kustomizations

# Check HelmReleases
flux get helmreleases -A

# Force reconcile
flux reconcile kustomization flux-system
flux reconcile helmrelease <name> -n <namespace>

# Check logs
flux logs --kind=Kustomization --name=flux-system -n flux-system
```

## Known Issues

- **kustomize-controller scheduling**: If the kustomize-controller pod lands on the worker node (cherrypi) and Flannel networking is degraded, DNS resolution for `source-controller.flux-system.svc.cluster.local` will time out. Restarting `k3s-agent` on cherrypi usually fixes this.
- **Node IP changes**: If a node's IP changes, restart `k3s-agent` on that node to re-register with the new IP and re-establish Flannel tunnels.
