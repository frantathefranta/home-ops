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
- `cluster.ca`, `cluster.aggregatorCA` (CP) — kept in `v1alpha1` to match onedr0p's
  pattern and preserve the existing base64-encoded PEM 1Password values. Their 1.14
  document replacements require literal PEM.
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
  the keys.
- `KubeNetworkConfig` has no CNI selector: "no CNI" is expressed by the *absence* of a
  `KubeFlannelCNIConfig` document.
- `KubeServiceAccountConfig.issuerURL` must keep matching the control-plane endpoint
  (`https://10.33.40.25:6443`). Its legacy base64-encoded PEM key is decoded by
  `render-config` because the document requires literal PEM.

## Verifying a template change

1. Snapshot the node's live config (also the rollback reference):
   `talosctl -n <node> get machineconfig v1alpha1 -o jsonpath='{.spec}' > /tmp/<node>-current.yaml`
2. Render the new config and diff locally (expect normalization noise):
   `just talos render-config <node> > /tmp/<node>-new.yaml && diff /tmp/<node>-current.yaml /tmp/<node>-new.yaml`
3. Dry-run the apply — the node validates the full config and reports how the
   change would be applied, without applying anything:
   `talosctl -n <node> apply-config --dry-run -f /tmp/<node>-new.yaml`

Then apply one worker first, then one control-plane node, before rolling the rest.
1.14 applies without a reboot by default (`--mode=reboot` is gone); if the dry-run
says a change needs a reboot, use `--mode=staged` or reboot explicitly after
cordoning/draining.