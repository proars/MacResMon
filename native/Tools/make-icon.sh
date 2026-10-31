#!/usr/bin/env bash
# Regenerates Resources/AppIcon.icns from Tools/make-icon.swift (needs only macOS tools: swift, sips, iconutil).
set -euo pipefail
cd "$(dirname "$0")/.."
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
swift Tools/make-icon.swift "$TMP/master.png"
SET="$TMP/AppIcon.iconset"; mkdir "$SET"
for spec in 16:16x16 32:16x16@2x 32:32x32 64:32x32@2x 128:128x128 256:128x128@2x 256:256x256 512:256x256@2x 512:512x512 1024:512x512@2x; do
  sips -z "${spec%%:*}" "${spec%%:*}" "$TMP/master.png" --out "$SET/icon_${spec#*:}.png" >/dev/null
done
iconutil -c icns "$SET" -o Resources/AppIcon.icns
echo "wrote Resources/AppIcon.icns"
