#!/usr/bin/env bash
# The Mac popover shot the website carries: build the macOS app, open the
# popover with sample data, photograph just that window, and write
# apps/api/public/screens/mac.webp.
#
#   make screens-mac
#
# Separate from `make screens` because this one builds and drives the real
# macOS app on this machine, not a simulator.
#
# Never full-screen `screencapture`: the popover is one window and the rest of
# the grab is whatever else is on the desk. The window is found by id and
# captured alone.
set -euo pipefail

cd "$(dirname "$0")/../../.."

DERIVED=${DERIVED:-/tmp/notifi-derived-mac}
SITE=apps/api/public/screens
OUT=${OUT:-/tmp/notifi-screens}
mkdir -p "$OUT"

xcodebuild -project apps/app/notifi.xcodeproj -scheme notifi-macOS \
  -configuration Debug -derivedDataPath "$DERIVED" \
  DEVELOPMENT_TEAM=Z28DW76Y3W build | tail -3

APP="$DERIVED/Build/Products/Debug/notifi.app"
[ -d "$APP" ] || { echo "no notifi.app in $DERIVED" >&2; exit 1; }

# A running copy would keep its own popover state; start clean.
pkill -x notifi 2>/dev/null || true
sleep 1

# `open`, not a backgrounded exec: a process spawned from a shell that exits
# is killed with it. NOTIFI_STICKY keeps the .transient popover from
# dismissing the moment focus moves to the screenshot tooling.
open --env NOTIFI_STICKY=1 --env NOTIFI_SAMPLE_DATA=1 \
     --env NOTIFI_SEED_SAMPLE=1 "$APP"
sleep 4

# One click opens it; the item toggles, so exactly one.
osascript -e 'tell application "System Events" to tell process "notifi" to click menu bar item 1 of menu bar 2' >/dev/null
sleep 3

# The popover window sits at layer 25; the tiny layer<0 entries are the
# status item itself. System python has no PyObjC, so ask Swift.
WINDOW_ID=$(swift - <<'EOF'
import CoreGraphics
let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as! [[String: Any]]
for w in list where (w["kCGWindowOwnerName"] as? String) == "notifi"
    && (w["kCGWindowLayer"] as? Int) == 25 {
    print(w["kCGWindowNumber"] as! Int)
    break
}
EOF
)
[ -n "$WINDOW_ID" ] || { echo "popover window not found — is it open?" >&2; exit 1; }

screencapture -x -o -l"$WINDOW_ID" "$OUT/mac.png"

# Scale-and-cover-crop to the size index.html declares, as webp.
python3 - "$OUT" "$SITE" <<'EOF'
import sys
from PIL import Image

out, site = sys.argv[1], sys.argv[2]
W, H = 840, 1296
im = Image.open(f"{out}/mac.png").convert("RGB")
scale = max(W / im.width, H / im.height)
im = im.resize((round(im.width * scale), round(im.height * scale)), Image.LANCZOS)
x, y = (im.width - W) // 2, (im.height - H) // 2
im.crop((x, y, x + W, y + H)).save(f"{site}/mac.webp", "WEBP", quality=82, method=6)
print(f"{site}/mac.webp")
EOF

# A Debug build shares the push identity with the installed app and has
# clobbered its APNs token by running. Kill it; relaunch the installed app
# afterwards so pushes keep arriving.
pkill -x notifi 2>/dev/null || true
echo "Debug build quit — relaunch your installed notifi so Mac push re-registers."
