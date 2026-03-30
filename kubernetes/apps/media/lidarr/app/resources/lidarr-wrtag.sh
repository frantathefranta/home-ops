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

# Lidarr's "Import Extra Files" functionality doesn't work currently: https://github.com/lidarr/Lidarr/issues/484
# This is a workaround for origin.yaml file that gets generated in transmission-music
ORIGIN_SRC="$(grep -rl "$${lidarr_download_id}" /music/downloads/lidarr/*/origin.yaml 2>/dev/null | head -1)"
if [[ -n "$${ORIGIN_SRC}" ]]; then
    echo "[lidarr-wrtag] Copying origin.yaml from $${ORIGIN_SRC} to $${ALBUM_DIR}"
    cp "$${ORIGIN_SRC}" "$${ALBUM_DIR}/origin.yaml"
else
    echo "[lidarr-wrtag] No origin.yaml found for hash $${lidarr_download_id}, continuing without it"
fi

echo "[lidarr-wrtag] Notifying wrtag for: $${ALBUM_DIR}"
curl \
    --fail \
    --request POST \
    --data-urlencode "path=$${ALBUM_DIR}" \
    "$${WRTAG_URL}"
