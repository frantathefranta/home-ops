#!/usr/bin/env bash
set -euo pipefail

DEST_BASE="/music/transmission/wrtag"
# WRTAG_API_KEY="key"   # replace with your actual wrtag API key
# WRTAG_URL="http://:${WRTAG_API_KEY}@127.0.0.1:7373/op/move"

SOURCE="$${TR_TORRENT_DIR}/$${TR_TORRENT_NAME}"
DEST="$${DEST_BASE}/$${TR_TORRENT_NAME}"

echo "[transmission-complete] Generating gazelle-origin file for $${TR_TORRENT_NAME}"
/app/.local/bin/gazelle-origin --tracker red "$${TR_TORRENT_HASH}" --out "$${TR_TORRENT_DIR}/$${TR_TORRENT_NAME}/origin.yaml"

echo "[transmission-complete] Copying '$${SOURCE}' → '$${DEST}'"
cp -rp "$${SOURCE}" "$${DEST}"

# echo "[transmission-complete] Notifying wrtag: ${DEST}"
# curl \
#   --fail \
#   --request POST \
#   --data-urlencode "path=${DEST}" \
#   "${WRTAG_URL}"

echo "[transmission-complete] Done."
