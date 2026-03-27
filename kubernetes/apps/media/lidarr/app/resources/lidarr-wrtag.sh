#!/usr/bin/env bash
set -euo pipefail

if [[ "$${lidarr_eventtype:-}" == "Test" ]]; then
    echo "[lidarr-wrtag] Test event received"
    exit 0
fi

if [[ "$${lidarr_eventtype:-}" != "AlbumDownload" ]]; then
    exit 0
fi

WRTAG_URL="http://:$${WRTAG_API_KEY}@wrtag.media.svc.cluster.local/op/move"
FIRST_TRACK="$(echo "$${lidarr_addedtrackpaths}" | cut -d'|' -f1)"
ALBUM_DIR="$(dirname "$${FIRST_TRACK}")"

echo "[lidarr-wrtag] Notifying wrtag for: $${ALBUM_DIR}"
curl \
    --fail \
    --request POST \
    --data-urlencode "path=$${ALBUM_DIR}" \
    "$${WRTAG_URL}"
