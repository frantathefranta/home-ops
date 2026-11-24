
# Table of Contents

1.  [Introduction](#org56a5c31)
2.  [Cloud dependency](#org689b93f)
3.  [Gatus](#gatus)

<a id="org56a5c31"></a>

# Introduction

This is my repo detailing home-ops based around Kubernetes (ran on Talos Linux).
It&rsquo;s based on the [cluster-template](https://github.com/onedr0p/cluster-template) generously created and maintained by [onedr0p](https://github.com/onedr0p). Slight modifications were made by me (because I don&rsquo;t know better).


<a id="org689b93f"></a>

# Cloud dependency

<table border="2" cellspacing="0" cellpadding="6" rules="groups" frame="hsides">


<colgroup>
<col  class="org-left" />

<col  class="org-left" />

<col  class="org-left" />
</colgroup>
<thead>
<tr>
<th scope="col" class="org-left">Service</th>
<th scope="col" class="org-left">Use</th>
<th scope="col" class="org-left">Cost</th>
</tr>
</thead>
<tbody>
<tr>
<td class="org-left">Akeyless</td>
<td class="org-left">External Secrets store</td>
<td class="org-left">$0/yr (for now)</td>
</tr>

<tr>
<td class="org-left">Google Cloud</td>
<td class="org-left">Hosting uptime-kuma</td>
<td class="org-left">$0/yr (free tier)</td>
</tr>

<tr>
<td class="org-left">Cloudflare</td>
<td class="org-left">Domain, Zero Trust tunnel, R2 storage</td>
<td class="org-left">~$7/yr</td>
</tr>

<tr>
<td class="org-left">GitHub</td>
<td class="org-left">Repo hosting, runners</td>
<td class="org-left">$0/yr</td>
</tr>

<tr>
<td class="org-left">Purelymail</td>
<td class="org-left">Email hosting for my domain</td>
<td class="org-left">$10/yr</td>
</tr>

<tr>
<td class="org-left">Pushover</td>
<td class="org-left">Notifications</td>
<td class="org-left">$5</td>
</tr>
</tbody>
</table>


<a id="gatus"></a>

# Gatus

[Gatus](https://status.franta.us) is managed by
`kubernetes/apps/observability/gatus/ks.yaml`. It uses the shared PostgreSQL
component on PostgreSQL 18, including its pgBackRest restore and backup
configuration. Generated discovery configuration is disposable (`emptyDir`);
endpoint history remains in PostgreSQL.

The discovery sidecar watches HTTPRoutes automatically and Services by annotation.
Gateway and route `gatus.home-operations.com/endpoint` annotations customize
checks. The existing internal Gateway uses guarded public-DNS checks: these
detect public A records, not internal service availability. Prometheus alerts
separate these exposure checks from endpoint failures.

The public status route attaches to `network/envoy-external`. Its explicit
self-check uses public DNS and Pushover; the route is excluded from discovery to
avoid duplicate checks. Akeyless `/pushover` supplies `PUSHOVER_USER_KEY`, and
`/gatus` supplies `GATUS_MAXI_PUSHOVER_TOKEN`, mapped to `GATUS_PUSHOVER_TOKEN`.
These existing fields must remain available before reconciliation.

The ConfigMap disables Flux substitution so Gatus expands its runtime environment
variables. Reloader restarts the pod after config or secret changes; discovered
endpoints hot-reload without a restart. Run one replica with `Recreate` to avoid
overlapping checks and notifications.

Render without changing the cluster:

```sh
flux build kustomization gatus --namespace observability \
  --path ./kubernetes/apps/observability/gatus/app \
  --kustomization-file ./kubernetes/apps/observability/gatus/ks.yaml \
  --dry-run --in-memory-build
```

Dry-run does not load cluster-wide substitutions or verify Akeyless fields,
PostgreSQL backup availability, Gateway readiness, or live endpoint reachability.
