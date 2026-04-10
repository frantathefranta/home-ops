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
FIRST_TRACK="$(echo "$${lidarr_addedtrackpaths:-}" | cut -d'|' -f1)"
ALBUM_DIR="$(dirname "$${FIRST_TRACK}")"

if [[ -z "$${ALBUM_DIR}" || "$${ALBUM_DIR}" == "." ]]; then
    echo "[lidarr-wrtag] ERROR: could not determine album directory from lidarr_addedtrackpaths='$${lidarr_addedtrackpaths:-}'"
    exit 1
fi

# Lidarr's "Import Extra Files" functionality doesn't work currently: https://github.com/lidarr/Lidarr/issues/484
# This is a workaround for origin.yaml file that gets generated in transmission-music
echo "[lidarr-wrtag] Searching for origin.yaml with hash $${lidarr_download_id:-}"
ORIGIN_SRC="$(grep -irl "$${lidarr_download_id:-}" /music/downloads/lidarr/*/origin.yaml 2>/dev/null | head -1 || true)"
if [[ -n "$${ORIGIN_SRC}" ]]; then
    echo "[lidarr-wrtag] Copying origin.yaml from $${ORIGIN_SRC} to $${ALBUM_DIR}"
    cp "$${ORIGIN_SRC}" "$${ALBUM_DIR}/origin.yaml"
else
    echo "[lidarr-wrtag] No origin.yaml found for hash $${lidarr_download_id:-}, continuing without it"
fi

FAILED_PATHS_LOG="/config/wrtag-failed-paths.log"

echo "[lidarr-wrtag] Notifying wrtag for: $${ALBUM_DIR}"
if ! curl \
    --fail \
    --show-error \
    --request POST \
    --data-urlencode "path=$${ALBUM_DIR}" \
    "$${WRTAG_URL}"; then
    echo "[lidarr-wrtag] ERROR: wrtag call failed for $${ALBUM_DIR}, logging to $${FAILED_PATHS_LOG}"
    echo "$(date --iso-8601=seconds) $${ALBUM_DIR}" >> "$${FAILED_PATHS_LOG}"
    exit 1
fi
