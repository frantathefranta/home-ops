# Envoy Gateway migration

Status: preparation-only deployment PR. No live cutover performed. Towonel is
deferred; keep the existing Cloudflare Tunnel for public applications other than
Forgejo.

## Preparation PR scope

This first deployment deliberately stops before DNS/origin cutover or Cilium
retirement:

- Reserve `${CLUSTER_LBA_V6_PREFIX}:15` for `network/envoy-forgejo` in Git.
  The suffix is unused in this checkout, **not verified unused in live IPAM**.
  Check all live Service allocations and the Cilium pool before merging.
- Use a gateway-specific IPv6 `EnvoyProxy`, with `mergeGateways: false` and a
  separate `envoy-forgejo` Service. `mergeType: StrategicMerge` inherits the
  existing image, replicas, resources, telemetry and local traffic policy from
  the GatewayClass configuration without changing either existing IP family.
- Restrict Forgejo HTTPS to `git.franta.us` and HTTPRoutes in `default`, SSH22 to
  TCPRoutes in `default`, and HTTP80 to the shared redirect in `network`.
  Apply the existing Lua filter and backend policy to the new gateway. A
  separate client policy neither accepts PROXY protocol nor trusts incoming
  forwarded addresses; HTTP/3 is not enabled on this TCP-only edge.
- Exclude the new dataplane from the broad Envoy world-ingress policy. Permit
  world traffic only on its translated TCP ports 10022/10080/10443 and required
  IPv6 ICMP, including Packet Too Big. Cluster ingress remains allowed by the
  existing clusterwide policy. The upstream firewall is outside this checkout:
  before WAN testing, permit only TCP22/80/443 to the new IPv6 destination and
  preserve ICMPv6/PMTUD. Do not alter the existing public IPv4 port22 service.
- Add 25 internal, 8 external and 1 Forgejo **separate staging HTTPRoutes**.
  Existing routes, DNS targets and monitoring stay in place. Staging routes
  copy the same hostnames, backends, filters and timeouts, attach only to their
  new HTTPS listener, and disable ExternalDNS and Gatus discovery. Chart route
  mappings use YAML anchors to share their configuration where supported.
- Add the new Forgejo SSH parent alongside its existing `envoy-external`
  parent. Keep old SSH listeners for rollback. Extend Gatus's gateway filter
  for the eventual Forgejo cutover; its existing endpoint still checks the old
  production route during staging.
- Leave both DNS controllers, Cloudflared origin/DNSEndpoint, existing gateway
  DNS annotations, Cilium Gateway API, certificates and CRD ownership unchanged.
  The Forgejo Service advertises no DNS hostname. Existing Forgejo `ROOT_URL`,
  SSH hostname/port, Anubis, healthcheck, 300s timeout and native OIDC remain.

### Why staging routes are separate

The pinned ExternalDNS chart `1.24.0` bundles ExternalDNS `v0.24.0`. Its
[Gateway resolver](https://github.com/kubernetes-sigs/external-dns/blob/v0.24.0/source/gateway.go)
collects targets from every accepted parent Gateway, using **Gateway** target
annotations; it does not use HTTPRoute target overrides. Adding Envoy parents
to production routes would make PowerDNS see both old and new CNAME targets.
Changing shared Gateway targets would also affect applications already on
Envoy. Separate routes annotated
`external-dns.kubernetes.io/controller: none` avoid both changes.

The [EnvoyProxy merge implementation](https://github.com/envoyproxy/gateway/blob/v1.10.0/internal/gatewayapi/envoyproxy_merge.go)
and [Gatus gateway filter](https://github.com/home-operations/gatus-sidecar/blob/0.6.1/internal/config/config.go)
support the gateway-specific configuration and repeated gateway-name arguments
used here.

### Deployment and acceptance

Before merging, confirm the reserved address is free and routed to the cluster,
and that upstream rules prevent direct WAN access to the internal Gateway and
tunnel-only application paths.
Record current public and LAN DNS values for `git.franta.us`, representative
internal/public applications, and both ingress endpoints. Identify the current
writers for the direct public ingress record and Forgejo records before any
later DNS PR; this preparation does not take ownership of either.

After Flux reconciles this PR:

1. Check the new Gateway is `Accepted` and `Programmed`, has only its reserved
   IPv6 address, and owns a separate Deployment and Service:

   ```sh
   kubectl -n network get gateway envoy-forgejo -o yaml
   kubectl -n network get deploy,svc \
     -l gateway.networking.k8s.io/gateway-name=envoy-forgejo
   kubectl get httproute,tcproute -A
   ```

2. Check `Accepted=True` and `ResolvedRefs=True` for each staging route's Envoy
   parent and the Forgejo TCPRoute's new parent. There should be 34 staging
   HTTPRoutes, with all original parents still accepted. Verify the actual
   Service target ports match the Cilium policy before opening the firewall.
3. Test Forgejo without changing DNS:

   ```sh
   IP=$(kubectl -n network get gateway envoy-forgejo \
     -o jsonpath='{.status.addresses[0].value}')
   curl --resolve "git.franta.us:443:[$IP]" \
     https://git.franta.us/api/healthz
   curl --head --resolve "git.franta.us:80:[$IP]" http://git.franta.us/
   ssh -o "HostName=$IP" -o HostKeyAlias=git.franta.us -T git@git.franta.us
   ```

   Require a valid wildcard certificate, passing health JSON, and an HTTPS
   redirect. Forgejo SSH may return a nonzero exit status when no interactive
   shell is offered; inspect authentication output. Use the same SSH connection
   override for real Git fetch/push on a disposable authorized repository.
   Test HTTPS/LFS, Anubis, OIDC callbacks and source addresses with a temporary
   client resolver override so browser redirects keep using this gateway.
4. Use connection overrides to test all internal/external staging routes,
   including existing Envoy `sso.franta.us` and `status.franta.us`. Verify backend
   TLS, uploads, streaming/WebSockets, timeouts and monitoring. Confirm public
   and LAN DNS values and Cloudflared's origin remain unchanged.

No live acceptance is claimed from local rendering. Do not remove original
routes, publish Forgejo DNS or close rollback paths until the later cutover
gates below pass.

### Preparation rollback

Revert the preparation commit through Git and reconcile Flux. This removes the
staging routes and new Forgejo parent/dataplane, restores the shared policies
and Gatus filter, and leaves production DNS/origins untouched. `cilium-config`
has pruning disabled, so explicitly delete `kube-system/hubble-ui-staging` after
the revert; do not delete its production route, either Cilium Gateway, CRDs or
certificate chain. Remove any upstream firewall allowance added for the new
address.

During a later cutover, replace the production routes' parents with the tested
Envoy parents, remove staging copies, update DNS/origin ownership deliberately,
and then retire Cilium resources only after validation and propagation.

## Non-negotiable exposure constraints

- Only one public IPv4 address is available, and it already serves other things.
- TCP22 on that public IPv4 is already in use and cannot be assigned to Forgejo.
- Forgejo SSH must use port22. Alternate public SSH ports are not acceptable.
- Keep `git.franta.us` for both HTTPS and SSH.
- IPv6-only public access to Forgejo is acceptable. IPv4-only clients will not
  reach either Forgejo HTTPS or SSH under this design.
- Do not introduce a VPS, Towonel edge, alternate SSH hostname, or client-side
  tunnel software to solve Forgejo exposure.

## Target architecture

Three separate Gateways, all managed by the existing Envoy Gateway controller:

| Gateway | Exposure | Purpose |
| --- | --- | --- |
| `network/envoy-forgejo` | Dedicated directly reachable IPv6 LoadBalancer | `git.franta.us` HTTPS443 and SSH22 |
| `network/envoy-external` | Existing Cloudflare Tunnel | All other public application HTTP(S) routes |
| `network/envoy-internal` | Direct LAN/VPN LoadBalancer | Internal application HTTP(S) routes |

- Publish a DNS-only AAAA record for `git.franta.us` pointing at the dedicated
  Forgejo gateway's reserved global IPv6 address. No public A record, Cloudflare
  proxying, or tunnel CNAME for this hostname.
- Keep Forgejo's `ROOT_URL: https://git.franta.us`,
  `SSH_DOMAIN: git.franta.us`, and advertised `SSH_PORT: 22`.
- Reparent both Forgejo's HTTPRoute and TCPRoute to `envoy-forgejo`.
- Preserve HTTPS routing through Anubis, the current healthcheck, request header
  handling, 300s request timeout, and native Kanidm OIDC.
- `ingress-external.franta.us` becomes a proxied CNAME to the existing Cloudflare
  Tunnel. Cloudflared sends apex/wildcard HTTPS to Envoy rather than Cilium.
- LAN DNS for `git.franta.us` resolves to the same dedicated Forgejo gateway,
  supporting both protocols without attaching Forgejo to either other Gateway.
- Cilium remains the CNI, LB IPAM, BGP, network-policy, and Hubble provider, but
  no longer serves Gateway API ingress.

Forgejo is directly exposed and does not receive Cloudflare's HTTP protection.
Do not expose the internal Gateway to the WAN as a substitute. Preserve Anubis
and existing authentication, and restrict the dedicated gateway to Forgejo routes.

## Baseline and dependencies

The earlier repository inventory found 33 remaining Cilium HTTPRoute parent
references: 25 internal and 8 external. Reconfirm the inventory at implementation.

- Forgejo currently attaches both HTTPS and SSH to `envoy-external`.
- Cloudflared currently forwards apex/wildcard traffic to Cilium's external
  Service, using `external.franta.us` as the origin TLS name.
- Public external-dns currently selects only Gateway `external` and globally
  enables Cloudflare proxying. Internal PowerDNS watches HTTPRoutes and Services.
- Public `ingress-external.franta.us` was observed resolving directly to Envoy's
  IPv6 LB address. Its DNS writer is not defined in this checkout; identify it
  before replacing that record. Establish ownership of Forgejo's DNS records too.
- The shared EnvoyProxy is dual-stack. Configure IPv6 specifically for the new
  Forgejo gateway without changing the existing gateways' address families.
- Envoy's certificate renewal/export chain and shared Gateway API CRDs currently
  live under Cilium configuration.
- `cilium-config` has `prune: false`; removing manifests alone will not delete
  retired live resources.

## 1. Prepare the dedicated Forgejo gateway

- Add `envoy-forgejo` to the existing network Envoy gateway deployment, with its
  own LoadBalancer Service and reserved, unused global IPv6 address from the
  Cilium pool. Ensure the selected Envoy configuration does not merge it with
  another Gateway's Service or dataplane.
- Use gateway-specific IPv6 EnvoyProxy configuration rather than changing the
  shared dual-stack configuration.
- Add HTTPS443 using the existing wildcard certificate and TCP22 for SSH.
  Restrict HTTPS to `git.franta.us` and route attachment to the required
  application namespace/kinds. SSH has no hostname/SNI routing; the dedicated
  address and TCPRoute identify its backend.
- Add HTTP80 only for an explicit HTTPS redirect, not plaintext application
  serving. Update the shared redirect route if reusing it.
- Review shared BackendTrafficPolicy/ClientTrafficPolicy and gateway-specific
  Lua policy targeting. Preserve intended Forgejo behavior and prevent untrusted
  WAN clients from spoofing source addresses through optional PROXY headers.
- Permit only the intended inbound ports on this dedicated IPv6 destination in
  the upstream firewall and Cilium policy. Preserve required IPv6 ICMP/PMTUD.
  IPv6 uses routed reachability, not the occupied public IPv4's port forwarding.

## 2. Move Forgejo without changing its hostname or ports

- Stage Forgejo's HTTPS and SSH attachment to the new gateway while retaining
  the old path for rollback. Pin existing DNS during temporary dual attachment.
- Verify HTTPS certificate/Anubis/OIDC and ordinary SSH through the new IPv6
  address using connection overrides before switching authoritative DNS.
- Extend public external-dns selection using a public-Gateway label filter:
  include Forgejo, Envoy external, and temporarily Cilium external; exclude
  internal Gateways.
- Explicitly disable Cloudflare proxying for Forgejo's generated DNS records;
  the controller's global `--cloudflare-proxied` default must not proxy them.
  Verify the annotation/provider-specific behavior against the installed
  external-dns version and inspect the resulting Cloudflare record settings.
- Publish DNS-only `git.franta.us` AAAA to the new reserved IPv6 address. Remove
  conflicting A/CNAME records and reconcile internal PowerDNS to the same
  gateway. Do not change unrelated records sharing the public IPv4.
- After DNS propagation and successful Git HTTPS/LFS and SSH operations, remove
  Forgejo's old gateway attachments.
- Remove unused SSH listeners from `envoy-external` and `envoy-internal`.

## 3. Move other public applications behind the existing tunnel

- Temporarily attach the eight remaining Cilium external routes to Envoy while
  preserving old DNS targets and Cilium coverage during staging.
- Ensure `sso.franta.us` and `status.franta.us` are ready on Envoy. Forgejo's
  authentication still depends on Kanidm even though Forgejo itself is direct.
- Test Envoy route acceptance and TLS before changing cloudflared's origin.
- Switch cloudflared's apex/wildcard origin to Envoy's actual Service on443,
  preserving HTTP Host headers and certificate verification. Use an origin TLS
  name covered by the existing certificate, such as `ingress-external.franta.us`.
  Forgejo has no application route on this gateway and is not tunnel-served.
- Replace the public `ingress-external.franta.us` direct AAAA with a proxied
  CNAME to the existing tunnel after resolving its current DNS writer.
- Move the other public application DNS targets to this endpoint. Maintain
  Cloudflare proxying for these records, unlike Forgejo's explicit DNS-only
  exception. Keep internal PowerDNS's direct gateway resolution.
- Remove temporary Cilium route attachments only after validation and DNS
  propagation. Retire `external.franta.us` only when no remaining targets use it.

## 4. Complete the internal migration and retire Cilium Gateway API

- Reparent the 25 internal route references to `network/envoy-internal`,
  preserving hostnames, aliases, and HTTPS listener selection.
- Preserve native application OIDC, backend TLS, application timeouts,
  monitoring annotations, Hubble's UI route, and independent transport Services.
  Do not introduce gateway OIDC as part of this migration.
- Move certificate renewal/Akeyless distribution and shared Gateway API CRD
  ownership out of Cilium-specific deployment paths without deleting the live
  certificate chain or CRDs.
- Explicitly delete retired Cilium Gateways after all dependencies are removed,
  accounting for `cilium-config`'s disabled pruning.
- Disable Cilium Gateway API only when no routes or tunnel origins depend on
  it. Do not automatically disable unrelated Cilium Envoy/L7 functionality.
- Keep Cloudflared and its credentials, dashboard, and DNS endpoint management.
  Update its endpoint resource rather than deleting the tunnel deployment.

## Validation and rollback gates

Before removing old paths, verify:

- Forgejo has a separate gateway/dataplane and IPv6 LoadBalancer address.
- Public and LAN `git.franta.us` resolve to the dedicated address; public DNS
  has no A record or proxied Cloudflare address for this hostname.
- External IPv6 clients reach HTTPS443 and SSH22 on the same hostname.
  IPv4-only failure is an accepted limitation, not a reason to add another port.
- Real Git SSH authentication/fetch/push and Git HTTPS/LFS work; certificates,
  Anubis, OIDC callbacks, source IPs, and request timeouts remain correct.
- Existing IPv4 SSH service and other applications on that address are unchanged.
- Other public apps work through Cloudflare/Tunnel/Envoy; LAN-only apps remain
  private. Check webhooks, WebSockets/streaming, uploads, HTTP redirects, and
  Kanidm backend TLS.
- Gatus retains Forgejo monitoring after its Gateway name changes; the current
  discovery filter selects only `envoy-external` and needs explicit adjustment.
- No direct WAN bypass exists for the tunnel-only or internal gateways.

Keep old route coverage, DNS values, and cloudflared origin configuration until
each stage passes and DNS propagation settles. Roll back the relevant DNS and
attachments together, ensuring the old destination still serves both Forgejo
protocols before directing clients back. Cloudflared remains part of the final
architecture; there is no Towonel deployment or edge-host migration in scope.
