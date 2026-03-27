#!/usr/bin/env bash
set -euo pipefail

if echo "$${TR_TORRENT_TRACKERS}" | grep -q "flacsfor.me"; then
    TRACKER="red"
elif echo "$${TR_TORRENT_TRACKERS}" | grep -q "home.opsfet.ch"; then
    TRACKER="ops"
else
    echo "[transmission-complete] Unknown tracker: $${TR_TORRENT_TRACKERS}"
    exit 1
fi

echo "[transmission-complete] Generating gazelle-origin file for $${TR_TORRENT_NAME} (tracker: $${TRACKER})"
/app/.local/bin/gazelle-origin --tracker "$${TRACKER}" "$${TR_TORRENT_HASH}" --out "$${TR_TORRENT_DIR}/$${TR_TORRENT_NAME}/origin.yaml"

echo "[transmission-complete] Done."
