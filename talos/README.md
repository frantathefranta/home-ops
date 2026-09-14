# Talos

Declarative [Talos Linux](https://talos.dev) machine configuration for the cluster, built from
composable multi-document patches (Talos 1.14 config style). Nothing in this directory is applied
automatically; configs are rendered on demand and pushed to nodes with `talosctl`.

## Layout

| Path                                    | Purpose                                                                   |
| --------------------------------------- | ------------------------------------------------------------------------- |
| `cluster.yaml.j2`                       | Documents applied to every node                                           |
| `controlplane.yaml.j2`                  | Control-plane-only documents, including `machine.type`                    |
| `workers.yaml.j2`                       | Worker-only documents                                                     |
| `nodes/<role>/<node>.yaml.j2`           | Per-node documents (hostname, links, zone)                                |
| `nodes/<role>/<node>.schematic.yaml.j2` | Optional per-node schematic override                                      |
| `schematic.yaml.j2`                     | Shared [Image Factory](https://factory.talos.dev) schematic               |
| `mod.just`                              | Recipes (`just talos ...`)                                                |

## Rendering

`just talos render-config <node>` builds the final machine config in three layers:

```
talosctl machineconfig patch <(cluster.yaml.j2) \
    -p @<(controlplane.yaml.j2 | workers.yaml.j2) \
    -p @<(nodes/<role>/<node>.yaml.j2)
```

Each layer passes through `minijinja-cli` (schematic ID and installer type arrive as `-D`
defines); the dual-stack `${CLUSTER_*_V6_CIDR}` values are `op://` references resolved by
`talosctl` like every other secret. `talosctl` then
strategically merges the layers: documents with the same kind/name are deep-merged, new documents
are appended.

Directory placement is the single source of truth for a node's role: the role patch is chosen by
which `nodes/<role>/` directory contains the node file, and `machine.type` is set by the role
patch.

Secrets never live in this repo. All sensitive values are `op://kubernetes/talos/...` references
resolved at render time.

## 1.14 config status

The config is migrated to the 1.14 multi-document style except for the residue that has no
document equivalent (or none we can use yet):

- `machine.ca`, `machine.certSANs`, `machine.token`, `machine.features`, `cluster.token` —
  still `v1alpha1` by design, no replacement document.
- `machine.kubelet` (incl. `nodeIP`) + `machine.nodeLabels` — pinned to `v1alpha1` by
  `kubelet.extraMounts`, which has no 1.14 document equivalent (OpenEBS local PV). v1alpha1
  fields are mutually exclusive with their replacement documents, so no `KubeletConfig` /
  `KubeNodeConfig` documents can coexist with that block. If Sidero ships an `extraMounts`
  equivalent (or the storage moves to a `RawVolumeConfig` + device-provisioner flow), the whole
  block collapses into `KubeletConfig` / `KubeNodeConfig`.
- `cluster.allowSchedulingOnControlPlanes` (CP) — deprecated but still honoured; its
  `KubeNodeConfig` replacement has no flag equivalent, and this cluster carries no
  `KubeNodeConfig` docs, so the two cannot conflict.
- `cluster.etcd` (CP) — still `v1alpha1`, no replacement document.

## Gotchas

- `machine.ca` / `cluster.ca` (v1alpha1) merge as a cert+key **unit**: a patch supplying only
  `key` blanks `crt`. `controlplane.yaml.j2` therefore repeats the `crt` references alongside
  the keys. (The 1.14 `KubeAPIServerCAConfig` document does *not* have this quirk — the base
  doc carries `issuingCA.cert` and the CP patch adds `issuingCA.key`; the merged result is
  verified by the render diff.)
- `KubeNetworkConfig` has no CNI selector: "no CNI" is expressed by the *absence* of a
  `KubeFlannelCNIConfig` document.
- The `KubeServiceAccountConfig` `issuerURL` must keep matching the control plane endpoint
  (`https://10.33.40.25:6443`); in the old v1alpha1 form it was derived implicitly.

## Verifying a template change

1. Render before/after and diff, for one CP and one worker:
   `just talos render-config <node> > /tmp/after.yaml`
2. On each node (or the affected role), confirm the apply would be a no-op where expected:
   `just talos render-config <node> | talosctl -n <node> machineconfig diff -f /dev/stdin`

Then apply one worker first, then one control-plane node, before rolling the rest.