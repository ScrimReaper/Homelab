# ADR-005 — Flux Repository Structure and Secret Management

**Date:** 2026-03-29
**Status:** Decided

## Context

With Flux bootstrapped, we need a consistent structure for managing infrastructure controllers, their CRD-based config, and application workloads — with proper ordering guarantees and safe secret handling in Git.

## Decision

### Repository layout

Three tiers managed by separate Flux Kustomizations:

| Kustomization | Path | Purpose |
|---|---|---|
| `infra-controllers` | `k8s/infrastructure/controllers/` | Install controllers (MetalLB, Traefik) |
| `infra-configs` | `k8s/infrastructure/configs/` | CRD-based config (IPAddressPool, etc.) |
| `apps` | `k8s/apps/` | Application HelmReleases |

`infra-configs` has `dependsOn: infra-controllers` and `apps` has `dependsOn: infra-configs`. This ensures CRDs exist before resources that use them are applied.

### Secret management

Secrets are encrypted with **SOPS + age** before committing to Git. Flux's kustomize-controller decrypts them automatically using an age private key stored as a cluster secret (`sops-age` in `flux-system`).

Only `data` and `stringData` fields are encrypted (per `.sops.yaml`), keeping the rest of the manifest readable.

## Consequences

- All secrets are safe to commit — the repo is the full source of truth including sensitive config
- CRD ordering is guaranteed — no race conditions between controller install and CRD resource creation
- Adding new infrastructure controllers or apps is consistent: add a subdirectory, reference it from the parent `kustomization.yaml`
- The age private key must be backed up separately — losing it means losing the ability to decrypt all secrets in the repo
