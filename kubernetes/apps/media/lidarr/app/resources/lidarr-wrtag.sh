#!/usr/bin/env bash
set -euo pipefail

printenv | grep -i lidarr | sort

if [[ "$${lidarr_eventtype:-}" == "Test" ]]; then
    echo "[lidarr-wrtag] Test event received"
    exit 0
fi

if [[ "$${lidarr_eventtype:-}" != "AlbumDownload" ]]; then
    exit 0
fi

WRTAG_URL="http://:$${WRTAG_API_KEY}@wrtag.media.svc.cluster.local/op/copy"
ALBUM_DIR="$(dirname "$${lidarr_trackfile_path}")"

echo "[lidarr-wrtag] Notifying wrtag for: $${ALBUM_DIR}"
curl \
    --fail \
    --request POST \
    --data-urlencode "path=$${ALBUM_DIR}" \
    "$${WRTAG_URL}"
