#!/usr/bin/env bash
set -euo pipefail

# qBittorrent substitutes %K %I "%D" "%R" after splitting the command.
torrent_id=$1
infohash_v1=$2
save_path=$3
root_path=$4

echo "[qbittorrent-complete] Contacting nemorosa for $${torrent_id}"
if ! curl --fail --silent --show-error --request POST \
    --header "Authorization: Bearer $${NEMOROSA_API_KEY}" \
    --output /dev/null \
    "http://127.0.0.1:8256/api/webhook?infohash=$${torrent_id}"; then
    echo "[qbittorrent-complete] nemorosa webhook failed for $${torrent_id}" >&2
fi

# Query all trackers; qBittorrent's %T only reports the current tracker.
tracker_hosts=$(curl --fail --silent --show-error \
    "http://127.0.0.1:8080/api/v2/torrents/trackers?hash=$${torrent_id}" |
    jq -r '.[].url | capture("://(?<host>[^/:?#]+)").host')
if grep -Fxq flacsfor.me <<< "$${tracker_hosts}"; then
    tracker=red
elif grep -Fxq home.opsfet.ch <<< "$${tracker_hosts}"; then
    tracker=ops
else
    echo "[qbittorrent-complete] No supported tracker for $${torrent_id}" >&2
    exit 1
fi

# Without a torrent root, writing origin.yaml or copying would target a shared directory.
if [[ ! -d "$${root_path}" || "$${infohash_v1}" == "-" ]]; then
    echo "[qbittorrent-complete] Skipping origin and wrtag: no torrent root or v1 infohash for $${torrent_id}" >&2
    exit 0
fi

echo "[qbittorrent-complete] Generating origin for $${root_path} (tracker: $${tracker})"
gazelle-origin --tracker "$${tracker}" "$${infohash_v1}" --out "$${root_path}/origin.yaml"

if [[ "$${save_path%/}" == /music/downloads ]]; then
    echo "[qbittorrent-complete] Notifying wrtag (copy) for: $${root_path}"
    curl --fail --request POST --data-urlencode "path=$${root_path}" \
        "http://:$${WRTAG_API_KEY}@wrtag.media.svc.cluster.local/op/copy"
fi

echo "[qbittorrent-complete] Done."
