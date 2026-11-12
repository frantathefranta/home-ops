# PostgreSQL upgrades through Git

Two PRs per app or batch: **upgrade**, then **restore**. This example upgrades
17 → 18 for apps using `kubernetes/components/postgres`. Assume healthy databases
and available backups. Leave Flux and Helm running; make cluster changes through Git.

## PR 1 — Run the upgrade

Under `kubernetes/apps/<namespace>/<app>/`:

1. Set app/worker replicas to zero in `app/helmrelease.yaml`. Record the original
   settings. Disable app HPAs and scheduled writers through Git too.
2. Add `app/pgupgrade.yaml` and include it in `app/kustomization.yaml`:

```yaml
apiVersion: postgres-operator.crunchydata.com/v1beta1
kind: PGUpgrade
metadata:
  name: <cluster>-17-to-18
  namespace: <namespace>
spec:
  postgresClusterName: <cluster>
  fromPostgresVersion: 17
  toPostgresVersion: 18
```

3. Add this under `spec` in the app's Flux `ks.yaml`:

```yaml
  patches:
    - target:
        group: postgres-operator.crunchydata.com
        version: v1beta1
        kind: PostgresCluster
      patch: |-
        - op: add
          path: /metadata/annotations
          value:
            postgres-operator.crunchydata.com/allow-upgrade: <cluster>-17-to-18
        - op: add
          path: /spec/shutdown
          value: true
```

Replace the placeholders; preserve any existing annotations. Target by kind
because the resource is still named `${APP}` when Kustomize patches it; Flux
substitutes the app name afterward.

Keep the desired PostgreSQL version at **17**. Merging starts the outage; app
scaling and database shutdown reconcile independently.

**Wait for every PGUpgrade in the batch to report `Succeeded=True` before merging
PR 2.** If an upgrade fails, stop and diagnose. A merged PR is not proof of success.

## PR 2 — Restore the apps on 18

- Add `PG_VERSION: "18"` to `spec.postBuild.substitute` in each app's `ks.yaml`.
- Remove the temporary shutdown/authorization patch, leaving unrelated patches alone.
- Restore the original app/worker replicas, HPAs, and schedules.
- Delete `app/pgupgrade.yaml` and its resource entry where pruning is enabled.
  With `prune: false`, keep the completed inert PGUpgrade tracked; removing its
  manifest would not delete it. Do not enable app-wide pruning just for cleanup.

Save wanted upgrade logs before merging: pruning PGUpgrade also removes its jobs
and pods. Merge only with the user's approval. No third cleanup PR is needed.

## Branching and validation

Prefer branching PR 2 from `main` after PR 1 merges. If drafted earlier as a
stacked PR, retarget it to `main` and **rebase after a squash merge**:

```bash
git fetch origin
git rebase --onto origin/main "$PREPARE_TIP" "$FINISH_BRANCH"
git diff origin/main...HEAD -- "$APP_DIR"
git push --force-with-lease
```

`PREPARE_TIP` is the original prepare-branch tip, not the squash commit on `main`.
A stale stack can actually preserve shutdown and zero replicas—not just display
an incomplete diff. GitHub saying "mergeable" is not sufficient.

Render each stage locally:

```bash
flux build kustomization "$FLUX_KS" --namespace "$FLUX_NS" \
  --path "$APP_DIR/app" --kustomization-file "$APP_DIR/ks.yaml" \
  --dry-run --in-memory-build
```

Dry-run skips cluster-provided substitutions; supply local test values if needed.
For PR 2, also inspect `git merge-tree --write-tree origin/main HEAD` and the
resulting tree with `git show <tree>:<file>`. Confirm the actual merge restores
app settings, selects 18, and removes shutdown. Branch rendering alone is not enough.

## Current rollout

All 14 clusters now request PostgreSQL 18 in Git. All upgrade/restore PRs are
merged; running versions were not checked from this session.

Examples: [upgrade #4255](https://github.com/frantathefranta/home-ops/pull/4255)
and [restore #4256](https://github.com/frantathefranta/home-ops/pull/4256).
Jellyseerr retains its completed PGUpgrade because pruning is disabled.

Remaining cleanup: once running versions are confirmed, change the shared default
from 17 to 18 and remove redundant per-app overrides.

A Git revert cannot undo upgraded data. Returning to 17 requires restoring a
pre-upgrade backup into a PostgreSQL 17 cluster.

[Crunchy major-version upgrade guide](https://access.crunchydata.com/documentation/postgres-operator/latest/guides/major-postgres-version-upgrade)
