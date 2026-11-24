# Envoy Gateway migration

Status: direct-cutover PR; brief downtime accepted. This checkout has not been
applied to the cluster. No parallel/staging HTTPRoutes are retained.

## Target architecture

| Gateway | Exposure | Purpose |
| --- | --- | --- |
| `network/envoy-forgejo` | Dedicated IPv6 LoadBalancer, `${CLUSTER_LBA_V6_PREFIX}:15` | `git.franta.us` HTTPS443 and SSH22 |
| `network/envoy-external` | Existing Cloudflare Tunnel; direct access only from LAN/VPN/cluster | Other public application HTTP(S) routes |
| `network/envoy-internal` | LAN/VPN/cluster only | Internal application HTTP(S) routes |

Only one public IPv4 exists and its TCP22 service must remain untouched.
Forgejo keeps `ROOT_URL: https://git.franta.us`, `SSH_DOMAIN: git.franta.us` and
advertised `SSH_PORT: 22`. IPv4-only clients cannot reach Forgejo under this
design. There is no alternate SSH port/hostname, VPS, Towonel or client tunnel.

## Declarative cutover

- The 25 internal and 8 external Cilium route references move directly to their
  Envoy HTTPS listeners. Original hostnames, aliases, backends, request filters,
  timeouts, monitoring and native application OIDC remain. All 34 preparation
  routes and their YAML anchors are removed.
- Forgejo's sole HTTPS and SSH parent is `envoy-forgejo`. HTTPS still goes through
  Anubis, retains `/api/healthz`, source-header handling and the 300s timeout, and
  uses native Kanidm OIDC. Forgejo is not protected by Cloudflare's HTTP edge.
  Gatus watches both public Envoy gateways, including Forgejo's healthcheck.
- Forgejo has a separate IPv6 Service/dataplane. Gateway-specific
  `EnvoyProxy.mergeType: StrategicMerge` inherits the existing image, resources,
  replicas, telemetry and local traffic policy; neither other gateway changes
  address family. Gateway merging is disabled.
- Only `git.franta.us` is accepted on Forgejo HTTP80/HTTPS443. HTTP80 attaches
  only the shared HTTPS redirect in `network`; HTTPS and SSH attachment is
  restricted to the required kinds in `default`. The direct client policy
  trusts socket addresses, not optional PROXY headers or incoming XFF.
- Public ExternalDNS selects Gateways labelled
  `external-dns.franta.us/public=true`: external and Forgejo, not internal.
  Forgejo's HTTPRoute sets
  `external-dns.kubernetes.io/cloudflare-proxied: "false"`. With an IPv6-only
  Gateway status and no target override, both DNS controllers generate the
  dedicated AAAA for `git.franta.us`, not an A record or tunnel CNAME.
- Other public application records target `ingress-external.franta.us`. The
  Cloudflared DNSEndpoint makes that name a proxied CNAME to the existing tunnel.
  PowerDNS continues watching Services, so the same ingress name resolves
  directly to Envoy on the LAN. Internal routes target `ingress-internal.franta.us`.
- Cloudflared sends apex/wildcard HTTPS to the explicitly named
  `envoy-external.network.svc.cluster.local:443` Service. TLS verification uses
  `ingress-external.franta.us`; the HTTP Host is not overridden. An explicit
  `git.franta.us` rule returns 404 rather than forwarding it to the wildcard
  origin. The credentials document's TunnelID now matches the existing run
  argument and DNSEndpoint UUID, `0d7a89f4-a717-47f1-82f0-252e07b01b63`.
- Non-Forgejo Envoy endpoints accept HTTP(S)/HTTP3 only from home IPv4
  `10.0.0.0/8`, home IPv6 `2600:1702:6630:3fe0::/60`, or cluster ingress.
  Public TCP access is limited to Forgejo's translated ports 10022/10080/10443.
  Cilium policies preserve ICMPv6 error handling, including PMTUD. This prevents
  a direct public application bypass even while upstream rules are updated.
- Shared Gateway API source/Kustomization manifests move to
  `kube-system/gateway-api/ks.yaml` with their existing names and namespace.
  The wildcard Certificate and Akeyless PushSecret move under
  `kube-system/gateway-certificate/app`, still targeting `kube-system` with the
  same Certificate, Secret and remote key names. Nothing deletes the live
  certificate/export chain or CRDs.
- Cilium's desired configuration disables only Gateway API. CNI, LB IPAM,
  BGP, network policy, Hubble settings, Envoy and L7 proxy settings are retained.
  Legacy Gateway manifests and unused SSH listeners are removed.

The pinned ExternalDNS chart `1.24.0` uses `v0.24.0`. Its
[Gateway source](https://github.com/kubernetes-sigs/external-dns/blob/v0.24.0/source/gateway.go)
takes targets from accepted Gateway parents and provider-specific annotations
from the HTTPRoute. Its
[Cloudflare provider](https://github.com/kubernetes-sigs/external-dns/blob/v0.24.0/provider/cloudflare/cloudflare.go)
honors the explicit `false` override despite the global proxied default.
Single-parent routes avoid conflicting PowerDNS CNAME targets.

## Before merging: required live checks

Local rendering cannot establish IP allocation, DNS ownership or upstream
firewall state. No kubeconfig is available in this checkout.

1. Confirm `${CLUSTER_LBA_V6_PREFIX}:15` is free in live Service/IPAM allocations,
   belongs to the Cilium pool, and is routed to the cluster. It is reserved only
   in Git until reconciliation.
2. Update the upstream firewall in the separate `nix-home` repository:
   `hosts/nixos-firewall/services/firewall-alternate/default.nix` currently has
   zone `envoy_external` at `2600:1702:6630:3fef:4040:2:0:14` and WAN rule
   `allow_envoy_external` permitting TCP22/80/443. Move this dedicated WAN
   allowance to the Forgejo destination ending `:15`; remove WAN access to
   external `:14` and keep internal `:13` private. Preserve ICMPv6/PMTUD and
   the existing public IPv4 SSH service. This PR does not modify that repository.
3. Identify and stop the current writers for the public ingress and Forgejo
   records, and check ownership of already-Envoy public names such as SSO and
   Gatus before the expanded selector adopts them. The ingress/Forgejo writers
   are not defined in this checkout or the adjacent firewall DNS bootstrap.
   Record old A/AAAA/CNAME values, Cloudflare proxy flags, TXT ownership and TTLs.
4. Arrange removal/adoption of conflicting records only for
   `ingress-external.franta.us` and `git.franta.us`. ExternalDNS must be allowed
   to own the desired records with its existing TXT identity; foreign-owned or
   unmanaged records will not necessarily be replaced automatically. Remove
   Forgejo's old A/CNAME and ingress's direct public AAAA without touching
   unrelated records that share the public IPv4.
5. Confirm the existing tunnel's secret corresponds to UUID
   `0d7a89f4-a717-47f1-82f0-252e07b01b63`, and the stated home/VPN CIDRs cover
   intended clients. The tunnel secret and AccountTag are not changed or retrieved.
6. Save the pre-migration revision and DNS/firewall state. Use a maintenance
   window; route, origin, DNS, Service replacement and Cilium rollouts are not
   atomic, and stale DNS can prolong client-visible downtime.

## Cutover order

Retired Cilium Gateways must be deleted **while the old Cilium Gateway API
controller is still enabled**, before reconciling the new disabled setting.
`cilium-config` has `prune: false`; removing YAML alone cannot retire them.

1. Before merging, suspend the old Cilium configuration reconciler to prevent
   recreation, then delete only its two Gateways and wait for their finalizers:

   ```sh
   flux suspend kustomization cilium-config -n kube-system
   kubectl -n kube-system delete gateway internal external --wait=true
   ```

   This begins the accepted outage for applications still on Cilium. Do not
   merge if deletion is stuck: inspect controller logs/finalizers while that
   controller remains enabled. Do not force-remove finalizers.
2. Merge the direct-cutover PR and reconcile the repository source and root
   application Kustomization. The existing `kube-system/gateway-api` objects are
   adopted at their new repository path; **do not delete this Kustomization**,
   whose pruning would delete cluster-scoped CRDs and routes.

   ```sh
   flux reconcile source git flux-system -n flux-system
   flux reconcile kustomization cluster-apps -n flux-system
   ```
3. Reconcile `gateway-certificate`, the Envoy controller and its gateways.
   Cloudflared depends on the gateways' current `Accepted`/`Programmed`
   conditions. The external gateway's Service is explicitly named
   `envoy-external`; wait for release of its old Service/IPAM allocation if the
   replacement initially reports an address conflict.

   ```sh
   flux reconcile kustomization gateway-api -n kube-system
   flux reconcile kustomization gateway-certificate -n kube-system
   flux reconcile kustomization envoy-gateway -n network
   flux reconcile kustomization envoy-gateway-gateway -n network
   ```
4. Reconcile the application routes, Cloudflared and both DNS controllers.
   Complete the previously arranged authoritative DNS ownership changes.
   Resume `kube-system/cilium-config` against the new revision; its remaining
   CNI/BGP/IPAM/network-policy resources stay managed. Cilium's new Helm values
   disable Gateway API without disabling unrelated Envoy/L7 functionality.

   ```sh
   flux reconcile kustomization cloudflared -n network
   flux reconcile kustomization external-dns-external -n network
   flux reconcile kustomization external-dns-powerdns -n network
   flux resume kustomization cilium-config -n kube-system
   flux reconcile kustomization cilium-config -n kube-system
   ```
5. If preparation manifests were ever applied, remove their stale staging
   resources as needed. In particular, explicitly delete
   `kube-system/hubble-ui-staging` because its old owner does not prune.
   The final desired manifests contain no staging routes.

## Acceptance

- All production HTTPRoutes have a single Envoy HTTPS parent with
  `Accepted=True` and `ResolvedRefs=True`; all three Gateways are `Accepted`
  and `Programmed`. No routes or tunnel origins reference Cilium ingress.
- Forgejo owns a separate IPv6-only LoadBalancer at the reserved address. Verify
  the generated ports and labels match the Cilium policy.
- Public and LAN `git.franta.us` resolve directly to that AAAA. Public DNS has
  no A/CNAME and Cloudflare proxying is disabled for this hostname.
- An external IPv6 client can use normal `git.franta.us` HTTPS443 and SSH22.
  Check certificate validation, Anubis, OIDC callbacks, `/api/healthz`, source
  IPs, Git fetch/push over SSH, Git HTTPS/LFS and 300s requests. IPv4-only failure
  is expected. The pre-existing IPv4 SSH service must be unchanged.
- Other public applications, especially `sso.franta.us` and `status.franta.us`,
  work through Cloudflare/Tunnel/Envoy. Test backend TLS, webhooks, uploads,
  WebSockets/streaming, redirects, timeouts and Gatus discovery.
- LAN/VPN clients retain direct gateway resolution. Neither internal nor
  tunnel-only application routes are reachable directly from a WAN client.
- Certificate renewal, PushSecret export, Envoy ExternalSecret import and
  shared Gateway API CRDs remain healthy under their new owners.

## Rollback

Restore the recorded pre-migration revision and DNS/firewall state together.
The earlier preparation commit is not the desired rollback target: use the
revision recorded before this PR was deployed.

Re-enable/reconcile Cilium Gateway API before recreating its Gateways and
restoring application parents and Cloudflared's old origin. Confirm the old
Forgejo destination serves both HTTPS and SSH before restoring its DNS.
Restore authoritative record ownership/proxy flags as well as values; allow
for TTL propagation. Certificate and CRD resource names/namespaces remain
unchanged, so their ownership transfer must not involve deletion. Cloudflared
remains deployed throughout; Towonel is out of scope.
