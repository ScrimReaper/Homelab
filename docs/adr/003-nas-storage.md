# ADR-003 — Dedicated NAS for cluster storage

**Date:** 2026-03-24
**Status:** Planned

## Context

The cluster will need more storage capacity beyond what individual Pi-attached drives can provide — both for expanding the Jellyfin media library and for hosting the Immich photo library. Running storage directly on a Pi (USB HDD array) is unreliable for 24/7 operation. A dedicated NAS decouples storage from compute, which is cleaner and more maintainable.

## Decision

Set up a dedicated NAS using a **used mini PC** (Lenovo ThinkCentre M series or HP EliteDesk Mini) running **TrueNAS Scale**, with NAS-rated HDDs in a ZFS mirror.

## Target Hardware

| Component | Choice | Notes |
|-----------|--------|-------|
| Host | Lenovo ThinkCentre M720q (or similar) | ~€70 used, ~10-15W idle, built for 24/7 |
| RAM | 16GB | TrueNAS recommends generous RAM for ZFS |
| OS drive | Small SSD (32GB+) | Separate from data drives |
| Data drives | 2x 4TB WD Red Plus or Seagate IronWolf | NAS-rated, built for 24/7 operation |
| RAID | ZFS mirror (RAID-Z1) | 4TB usable, 1 drive redundancy |

**Estimated cost:** ~€250 total

## Integration with k3s

TrueNAS exposes storage via NFS. The cluster uses [democratic-csi](https://github.com/democratic-csi/democratic-csi) to provision PersistentVolumes automatically from NFS shares. Pods request a PVC and the NAS handles allocation transparently.

## Consequences

- Storage is independent of any single Pi — a node failure doesn't affect the data
- ZFS provides checksumming, snapshots, and RAID redundancy
- Adds another device to maintain and power
- Old Dell laptop running Windows 7 is not suitable (poor airflow for 24/7, no drive bays, aging hardware)
