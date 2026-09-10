set quiet
set script-interpreter := ['bash', '-euo', 'pipefail']
set shell := ['bash', '-euo', 'pipefail', '-c']

[private]
default:
    just -l talos

[confirm('Apply Talos config to ' + node + ' [y|N] ?')]
[doc('Apply Talos config to a node')]
apply-node node *args:
    just talos render-config "{{ node }}" | talosctl -n "{{ node }}" apply-config -f /dev/stdin {{ args }}

[doc('Download Talos machine image')]
[script]
download-image version node="":
    export SCHEMATIC="$(just talos schematic-id "{{ node }}")"
    curl -fL --remove-on-error --retry 5 --retry-delay 5 --retry-all-errors --progress-bar \
        -o "{{ source_directory() }}/talos-{{ version }}-${SCHEMATIC:0:8}.iso" \
        "https://factory.talos.dev/image/${SCHEMATIC}/{{ version }}/metal-amd64.iso"
    just log info "Downloaded Talos" version "{{ version }}" schematic "${SCHEMATIC}"

[confirm('Reboot node ' + node + ' [y|N] ?')]
[doc('Reboot a node')]
reboot-node node:
    talosctl -n {{ node }} reboot -m powercycle

[doc('Render Talos config for a node')]
[script]
render-config node:
    # Load ${CLUSTER_*_V6_CIDR} from the sops-encrypted env (talconfig source of truth)
    while IFS= read -r line; do
        [[ "$line" =~ ^([A-Z0-9_]+):[[:space:]]+(.*)$ ]] && export "${BASH_REMATCH[1]}=${BASH_REMATCH[2]}"
    done < <(sops -d "{{ source_directory() }}/talenv.sops.yaml" | grep -E '^[A-Z0-9_]+: ')
    schematic="$(just talos schematic-id "{{ node }}")"
    role="controlplane"
    install_type="nocloud-installer"
    if [[ -f "{{ source_directory() }}/nodes/workers/{{ node }}.yaml.j2" ]]; then role="workers"; install_type="metal-installer"; fi
    talosctl machineconfig patch \
        <(just template "{{ source_directory() }}/cluster.yaml.j2" -D "schematic=${schematic}" -D "install_type=${install_type}" -D "role=${role}" | envsubst '${CLUSTER_POD_V6_CIDR} ${CLUSTER_SVC_V6_CIDR} ${CLUSTER_NODE_V6_CIDR}') \
        -p @<(just template "{{ source_directory() }}/${role}.yaml.j2" -D "role=${role}") \
        -p @<(just template "{{ source_directory() }}/nodes/${role}/{{ node }}.yaml.j2")

[confirm('Reset node ' + node + ' [y|N] ?')]
[doc('Reset a node')]
reset-node node *args:
    talosctl -n "{{ node }}" reset --system-labels-to-wipe STATE --system-labels-to-wipe EPHEMERAL --graceful=false {{ args }}

[confirm('Shutdown node ' + node + ' [y|N] ?')]
[doc('Shutdown a node')]
shutdown-node node *args:
    talosctl -n "{{ node }}" shutdown --force {{ args }}

[confirm('Upgrade Kubernetes to ' + version + ' [y|N] ?')]
[doc('Upgrade Kubernetes version on the cluster')]
upgrade-k8s version:
    talosctl -n "$(talosctl config info -o yaml | yq -r -e '.endpoints[0]')" upgrade-k8s --to {{ version }}

[confirm('Upgrade node ' + node + ' [y|N] ?')]
[doc('Upgrade node Talos version')]
upgrade-node node *args:
    talosctl -n "{{ node }}" upgrade -i "$(just talos machine-image "{{ node }}")" -m powercycle --timeout=10m {{ args }}

[private]
schematic-file node="":
    file="{{ source_directory() }}/schematic.yaml.j2"; if [[ -n "{{ node }}" ]]; then for f in "{{ source_directory() }}"/nodes/*/"{{ node }}".schematic.yaml.j2; do [[ -f "$f" ]] && file="$f"; done; fi; echo "$file"

[private]
schematic-id node="":
    role="controlplane"; if [[ -f "{{ source_directory() }}/nodes/workers/{{ node }}.yaml.j2" ]]; then role="workers"; fi; curl -sX POST --data-binary @<(just template "$(just talos schematic-file "{{ node }}")" -D "role=${role}") "https://factory.talos.dev/schematics" | jq -r '.id'

[private]
[script]
machine-image node="":
    export SCHEMATIC="$(just talos schematic-id "{{ node }}")"
    install_type="nocloud-installer"
    if [[ -f "{{ source_directory() }}/nodes/workers/{{ node }}.yaml.j2" ]]; then install_type="metal-installer"; fi
    just template "{{ source_directory() }}/cluster.yaml.j2" -D "schematic=${SCHEMATIC}" -D "install_type=${install_type}" -D "role=controlplane" | yq -r -e 'select(.kind == "UnattendedInstallConfig") | .installer.image'