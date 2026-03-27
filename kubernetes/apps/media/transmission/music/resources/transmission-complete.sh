#!/usr/bin/env bash
set -euo pipefail

DEST_BASE="/music/transmission/wrtag"
# WRTAG_API_KEY="key"   # replace with your actual wrtag API key
# WRTAG_URL="http://:${WRTAG_API_KEY}@127.0.0.1:7373/op/move"

SOURCE="$${TR_TORRENT_DIR}/$${TR_TORRENT_NAME}"
DEST="$${DEST_BASE}/$${TR_TORRENT_NAME}"

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

echo "[transmission-complete] Copying '$${SOURCE}' → '$${DEST}'"
cp -rp "$${SOURCE}" "$${DEST}"

# echo "[transmission-complete] Notifying wrtag: ${DEST}"
# curl \
#   --fail \
#   --request POST \
#   --data-urlencode "path=${DEST}" \
#   "${WRTAG_URL}"

echo "[transmission-complete] Done."
