# ADR-002 — Immich storage: physical SSD attachment over NFS

**Date:** 2026-03-24
**Status:** Decided

## Context

The Immich photo library (~1TB) currently lives on the main PC. When migrating Immich into the k3s cluster, the library storage needs to move with it (or be made accessible to the cluster).

Two options were considered:

1. **Physical attachment** — connect the 1TB SSD directly to the Pi 5 via USB 3.0
2. **NFS mount** — keep the SSD on the main PC and expose it as a network share

## Decision

**Physically attach the SSD to the Pi 5.**

## Reasoning

- Immich is I/O intensive: it performs thumbnail generation, video transcoding, and ML-based face/object detection on upload. NFS latency would directly degrade these operations.
- The Pi 5 has USB 3.0, enabling near-native SSD throughput.
- Simpler storage setup in k3s: a `local` PersistentVolume on the Pi 5 node, no NFS CSI driver or network dependency required.
- NFS would make sense for multi-node read access, but Immich is a single-writer workload — no benefit.

## Consequences

- The Pi 5 becomes the required node for the Immich workload (node affinity needed in the manifest)
- Physical migration of the 1TB library from the main PC is required (one-time, via `rsync` over LAN or physical transport)
- If the Pi 5 fails, the SSD data is safe but Immich is unavailable until the node recovers

## Notes

The Pi 5 already has a separate 1TB SSD (`/mnt/media`) used for the Jellyfin library. A second SSD for Immich would be needed, or the two libraries could share the same volume with separate directories.
