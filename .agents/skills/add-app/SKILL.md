---
name: add-app
description: Use when deploying a new application to the cluster — scaffolding a Flux Kustomization plus app-template HelmRelease under kubernetes/apps/ (new app, new service, "add X to the cluster")
---

# Add a New Application

Scaffolds `kubernetes/apps/<namespace>/<app>/` with a Flux Kustomization (`ks.yaml`) and an app-template HelmRelease. Every value below comes from current repo conventions — when in doubt, mirror a recent real app instead of inventing structure:

| Reference app                              | Shows                                                                  |
| ------------------------------------------ | ---------------------------------------------------------------------- |
| `kubernetes/apps/media/maintainerr`        | **The baseline** — lean ks.yaml, kopiur persistence, route, anchored probes |
| `kubernetes/apps/default/vikunja`          | postgres + dragonfly components, `healthCheckExprs`, secrets, env config |
| `kubernetes/apps/media/autobrr`            | ExternalSecret against Akeyless                                        |
| `kubernetes/apps/default/bar-assistant`    | config file via `configMapGenerator` (`config/` dir), multi-component app |

## Step 1: Gather details

Ask the user (ask_user_question) for anything not already given:

1. **App name** and **namespace** (existing dirs: `ls kubernetes/apps/`)
2. **Image** repository + tag (upstream's current release)
3. **Port** the app listens on, and whether it gets a **route**; internal (default) or public
4. **Persistence** — does the app store state? (→ kopiur component)
5. **Secrets** — from Akeyless? Get the key path (e.g. `/paperless`) AND the exact field names — a wrong field name renders an empty value with no error
6. **Config files** — mounted config? (→ configMapGenerator + `config/` or `resources/`)
7. **Dependencies** — other Flux Kustomizations or components this app needs (postgres? dragonfly?)

## Step 2: Create the files

Layout:

```
kubernetes/apps/<namespace>/<app>/
├── ks.yaml
└── app/
    ├── kustomization.yaml
    ├── ocirepository.yaml
    ├── helmrelease.yaml
    ├── externalsecret.yaml      # only if secrets
    └── config/                  # only if config files
```

### ks.yaml

Lean style (maintainerr) — no `commonMetadata`, no `timeout`, no `retryInterval`:

```yaml
---
# yaml-language-server: $schema=https://k8s-schemas.home-operations.com/kustomize.toolkit.fluxcd.io/kustomization_v1.json
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: &app <app>
spec:
  interval: 1h
  path: "./kubernetes/apps/<namespace>/<app>/app"
  prune: true
  sourceRef:
    kind: GitRepository
    name: flux-system
    namespace: flux-system
  targetNamespace: <namespace>
```

**`wait`:** omit it for a normal leaf app. Only add `wait: true` when another Kustomization will `dependsOn` this one AND this Kustomization defines no `healthChecks`/`healthCheckExprs` (that's what gives the dependent a readiness gate). If it does define `healthCheckExprs`, leave `wait` unset.

**If the app has persistence**, the kopiur component handles SnapshotPolicy, SnapshotSchedule, Restore, and the PVC — add the component, the rook dependency, and `postBuild`:

```yaml
spec:
  components:
    - ../../../../components/kopiur
  dependsOn:
    - name: rook-ceph-cluster
      namespace: rook-ceph-external
  postBuild:
    substitute:
      APP: *app
      # Optional overrides, only when defaults don't fit:
      # KOPIUR_CLAIM: <app>-data      # PVC name (default: ${APP})
      # KOPIUR_CAPACITY: 15Gi         # default: 5Gi
      # KOPIUR_MOVER_UID: "1000"      # default: 568
      # KOPIUR_MOVER_GID: "1000"      # default: 568
      # KOPIUR_STORAGECLASS: ceph-rbd # also KOPIUR_SNAPSHOTCLASS, KOPIUR_ACCESSMODES,
      # KOPIUR_COPY_METHOD, KOPIUR_CACHE_CAPACITY, KOPIUR_CACHE_STORAGECLASS
```

(All knobs and defaults: `kubernetes/components/kopiur/`.) Include `postBuild.substitute.APP` whenever any component is used; omit `components`/`postBuild` entirely otherwise. Other components follow the same pattern — e.g. `../../../../components/postgres` and `../../../../components/dragonfly` (see vikunja, including its `healthCheckExprs` for both).

### app/kustomization.yaml

```yaml
---
# yaml-language-server: $schema=https://json.schemastore.org/kustomization
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - ./externalsecret.yaml # only if secrets
  - ./ocirepository.yaml
  - ./helmrelease.yaml
```

**If the app mounts config files**, put them in `config/` (or `resources/`) and append:

```yaml
configMapGenerator:
  - name: <app>-configmap
    files:
      - config.yaml=./config/config.yaml
generatorOptions:
  disableNameSuffixHash: true
```

### app/ocirepository.yaml

```yaml
---
# yaml-language-server: $schema=https://k8s-schemas.home-operations.com/source.toolkit.fluxcd.io/ocirepository_v1.json
apiVersion: source.toolkit.fluxcd.io/v1
kind: OCIRepository
metadata:
  name: <app>
spec:
  interval: 15m
  layerSelector:
    mediaType: application/vnd.cncf.helm.chart.content.v1.tar+gzip
    operation: copy
  ref:
    tag: <version>
  url: oci://ghcr.io/bjw-s-labs/helm/app-template
```

**Never hardcode `<version>` from memory** — use the version the rest of the repo is on:

```bash
/usr/bin/grep -h "tag:" kubernetes/apps/*/*/app/ocirepository.yaml | sort | uniq -c | sort -rn | head -1
```

### app/helmrelease.yaml

```yaml
---
# yaml-language-server: $schema=https://k8s-schemas.home-operations.com/helm.toolkit.fluxcd.io/helmrelease_v2.json
apiVersion: helm.toolkit.fluxcd.io/v2
kind: HelmRelease
metadata:
  name: &app <app>
spec:
  interval: 30m
  chartRef:
    kind: OCIRepository
    name: <app>
  values:
    controllers:
      <app>:
        annotations:
          reloader.stakater.com/auto: "true" # only if secrets or config files
        pod:
          securityContext:
            runAsGroup: 2000
            runAsNonRoot: true
            runAsUser: 2000
        containers:
          app:
            image:
              repository: <image-repo>
              tag: <image-tag>@sha256:<digest>
            probes:
              liveness: &probes
                enabled: true
                custom: true
                spec:
                  httpGet:
                    path: /health
                    port: &port <port>
                  periodSeconds: 10
                  timeoutSeconds: 5
                  failureThreshold: 3
              readiness: *probes
            resources:
              requests:
                cpu: 10m
              limits:
                memory: 256Mi
            securityContext:
              allowPrivilegeEscalation: false
              capabilities:
                drop:
                  - ALL
    service:
      app:
        ports:
          http:
            port: *port
```

House style: use YAML anchors (`&app`, `&port`, `&probes`) the way maintainerr/vikunja do instead of repeating values. Adjust `runAsUser`/`runAsGroup` (and capabilities) to what the image requires; drop the pod `securityContext` only if the image genuinely can't run non-root.

**Image tags are digest-pinned** (`<tag>@sha256:<digest>`) — this is enforced across the repo; Renovate manages both afterwards. Get the digest for the tag you picked:

```bash
nix shell nixpkgs#crane -- crane digest <image-repo>:<image-tag>
```

**Optional value blocks** (top-level under `values`, alphabetical: `controllers`, `persistence`, `route`, `service`):

Route:

```yaml
route:
  app:
    hostnames:
      - "{{ .Release.Name }}.franta.us"
    parentRefs:
      - name: internal # external for public apps
        namespace: kube-system
```

(The literal `<app>.franta.us` form is fine too, e.g. when the subdomain differs from the release name. The Gateways are `internal`/`external` in `kube-system` — not `envoy-*`.)

Persistence (pairs with the kopiur block in ks.yaml; also add `fsGroup` + `fsGroupChangePolicy: OnRootMismatch` to the pod securityContext):

```yaml
persistence:
  data:
    existingClaim: <app> # must match KOPIUR_CLAIM if overridden
    globalMounts:
      - path: /data
```

`readOnlyRootFilesystem: true` is used by many apps but not universal — if you set it and the app writes to `/tmp`, add an `emptyDir` mounted at `/tmp`.

Config file mount (pairs with configMapGenerator):

```yaml
persistence:
  config:
    type: configMap
    name: <app>-configmap
    globalMounts:
      - path: /config/config.yaml
        subPath: config.yaml
        readOnly: true
```

Secrets: add to the container:

```yaml
envFrom:
  - secretRef:
      name: <app>-secret
```

### app/externalsecret.yaml (only if secrets)

Secrets come from **Akeyless** (`akeyless-secret-store`), not 1Password. Akeyless field names are already the final env var names — no rewrite needed:

```yaml
---
# yaml-language-server: $schema=https://k8s-schemas.home-operations.com/external-secrets.io/externalsecret_v1.json
apiVersion: external-secrets.io/v1
kind: ExternalSecret
metadata:
  name: <app>-secret
spec:
  refreshInterval: 15m
  target:
    name: <app>-secret
    template:
      engineVersion: v2
      data:
        SOME_ENV_VAR: "{{ .SOME_ENV_VAR }}"
  dataFrom:
    - extract:
        key: /<app>
      sourceRef:
        storeRef:
        kind: ClusterSecretStore
        name: akeyless-secret-store
```

Convention: `metadata.name` and the generated Secret are both `<app>-secret`, and `template.data` references the Akeyless field names directly (see autobrr, paperless). The `.<field>` references must use the real field names from Step 1 — a wrong field name renders an empty value with no error. If the field names weren't provided and you can't ask, insert `<FIXME: akeyless field name>` placeholders and call them out.

## Step 3: Register in the namespace kustomization

Add `./<app>/ks.yaml` to `kubernetes/apps/<namespace>/kustomization.yaml` `resources` (keep existing entries where they are).

**New namespace?** Create `kubernetes/apps/<namespace>/kustomization.yaml`:

```yaml
---
# yaml-language-server: $schema=https://json.schemastore.org/kustomization
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: <namespace>
resources:
  - ./<app>/ks.yaml
components:
  - ../../components/common
```

That's it — `components/common` supplies the Namespace object (its `name: not-used` placeholder gets renamed to the namespace by kustomize), `global-vars` (`cluster-settings`/`cluster-secrets`), alerts, and sops decryption. No separate `namespace.yaml`, and no registration anywhere else: the `cluster-apps` Kustomization points at `./kubernetes/apps` and picks new namespace dirs up automatically.

## Step 4: Verify and deploy

```bash
# Render the app locally (must succeed; ${APP} vars staying literal is expected)
flate build ks --namespace <namespace> --output yaml <app>

# Apply to the cluster (server-side, as kustomize-controller would)
just kube apply-ks <namespace> <app>
```

Show the user the created files and get confirmation before committing. Commit style: `Add <app>`.

## Common mistakes

- **Copying a chart version, image tag, or digest from this skill or memory** — always read the current chart version from the repo (Step 2 command) and resolve the image digest with `crane digest`. Plain tags without a digest are not the convention.
- **Using 1Password for secrets** — the repo migrated to Akeyless; the only store in use is `akeyless-secret-store`.
- **Using volsync** — the repo migrated to kopiur; `components/volsync` no longer exists.
- **Wrong Gateway names for routes** — `internal`/`external` in `kube-system`, not `envoy-internal`/`envoy-external` in `network`.
- **Forgetting `reloader.stakater.com/auto`** — without it, secret/config changes don't restart pods (only needed when the app has secrets or mounted config).
- **`readOnlyRootFilesystem: true` without handling `/tmp`** — apps that write there will crash; mount an `emptyDir`.
- **Adding `commonMetadata`, `timeout`, or `retryInterval` to `ks.yaml`** — the lean style (maintainerr) omits all three. Leave `wait` unset unless another Kustomization depends on this one and it has no `healthCheckExprs` (then `wait: true`).
- **Referencing non-existent paths** — the kopiur component is `kubernetes/components/kopiur` (no `backup/` subdir); there is no `selfhosted` namespace.