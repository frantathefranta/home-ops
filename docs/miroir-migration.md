# Miroir migration (replaces OpenEBS local PV)

Status: parked — research done, design decisions open.

## Goal

Replace OpenEBS local-PV hostpath with [miroir](https://github.com/home-operations/miroir)
(home-operations DRBD9-based CSI, docs at https://miroir.home-operations.com/). Removing
OpenEBS lets us drop `kubelet.extraMounts`, which is the last field pinning the `machine.kubelet`
block (and `nodeIP`/`nodeLabels`) to v1alpha1 — i.e. it completes the 1.14 multi-document
migration of the Talos config (see `talos/README.md`, "1.14 config status").

## Current OpenEBS footprint

- Deployed via `kubernetes/apps/openebs-system` (hostpath provisioner, basePath
  `/var/openebs/local` → the `extraMounts` entry in `talos/cluster.yaml.j2`).
- Only three PVCs on `openebs-hostpath`:
  - `kube-prometheus-stack` (two)
  - `actions-runner-controller` runner workspace (one)
- All re-creatable/restorable data → migration = new PVCs on the miroir StorageClass, move or
  re-cache the data, delete `openebs-system`.

## How miroir works (reference: onedr0p/home-ops)

Chain in his cluster:

```
RawVolumeConfig "miroir-slow"  →  unformatted partition r-miroir-slow on a spare NVMe
                                  (diskSelector: disk.model == "Corsair MP600 MICRO" && !system_disk)
schematic: siderolabs/drbd     →  DRBD9 kernel modules + userland (Talos >= 1.13 ext)
MiroirNodeGroup (CP nodes)     →  per-node LVM thin pool on /dev/disk/by-partlabel/r-miroir-slow,
                                  DRBD-replicated, replicaCount 2, over his thunderbolt bridge
StorageClass + VolumeGroupSnapshotClass → PVCs, lockstep snapshots
```

The CSI node plugin consumes devices via `/dev` directly — no kubelet host-path visibility,
hence no `extraMounts`.

Requirements: k8s >= 1.31 (we're on 1.37), 2–3 storage nodes, kernel modules only on the nodes
(`dm_thin_pool` + DRBD9; on Talos the `siderolabs/drbd` extension covers DRBD, add a
`KernelModuleConfig` for `dm_thin_pool`). Chart: `oci://ghcr.io/home-operations/charts/miroir`
(0.12.3 in his repo).

Backends: LVM thin (spare disk / raw partition per node), ZFS pool, or loopfile (a few GB on
root fs, no disk surgery). `replicas: "1"` = node-local (no DRBD, no extension needed);
`replicas: "2"` = DRBD-synced with quorum tie-breaker on the third node.

## Open design decisions

1. **Disks** — unknown. `talosctl get disks` on actinium/thorium/protactinium (and workers if
   they'd join). Spare disk → LVM thin on `RawVolumeConfig` partition. Single-disk minis →
   loopfile, or carve a partition off the system disk (aggressive).
2. **Interconnect** — what connects the three CPs and at what speed? DRBD sync replication is
   fine over a clean LAN, hazardous over a congested shared uplink. onedr0p uses a dedicated
   thunderbolt bridge.
3. **Replication appetite** — do the workloads (Prometheus TSDB, runner workspace) actually
   need 2-replica synchronous replication, or is node-local `replicas: "1"` the 90% solution
   with 10% of the moving parts?

## Implementation sketch (once decided)

1. Schematic: add `siderolabs/drbd` (if replicating) → new schematic ID → new image → upgrade
   the storage nodes.
2. Talos: `RawVolumeConfig` (per node or shared if same disk) + `KernelModuleConfig
   dm_thin_pool` on the storage nodes.
3. `kubernetes/apps/miroir-system`: namespace, OCIRepository + HelmRelease, `MiroirNodeGroup`
   (nodeSelector on the storage nodes), StorageClass (`replicas` param), VolumeSnapshotClass
   (+ VolumeGroupSnapshotClass if wanted).
4. Re-point the three PVCs to the miroir StorageClass; migrate/re-cache data; delete
   `openebs-system`.
5. Talos: remove `extraMounts` → move `machine.kubelet` into a `KubeletConfig` doc, `nodeIP` +
   `nodeLabels` into `KubeNodeConfig` docs (if CP nodes join the pool, move the kubelet block to
   `workers.yaml.j2` first so CP goes fully typed); revisit `allowSchedulingOnControlPlanes` via
   the CP `KubeNodeConfig` taints. Verify on one worker, then one CP.

## Risks / gotchas

- `RawVolumeConfig` changes the partition table → storage nodes need re-provisioning, not a
  hot patch.
- DRBD: pick the replication network deliberately; monitor diskless/quorum states during node
  maintenance (miroir docs: "Replication and quorum").
- Prometheus TSDB on a thin pool: set the PVC size with headroom for compaction; allowVolumeExpansion.
- The legacy `.taskfiles/Talos/Taskfile.yaml` still references the now-unused
  `talos/talenv.sops.yaml` (its `talconfig.yaml` precondition is already gone) — clean up
  separately.