#!/usr/bin/env bash
# The Mac popover shot the website carries: build the macOS app, open the
# popover with sample data, photograph just that window, and write
# apps/api/public/screens/mac-cut.webp (what index.html shows) and mac.webp.
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
mkdir -p "$SITE"   # not in the repo any more: the site shows the film, not these
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

# Scale to the size index.html declares, as webp — after squaring the figure
# with the site: the bar draws its bell at 50%, but a real capture clamps the
# popover against the screen edge, so its arrow sits off the panel's centre.
# The arrow is slid along the panel's top edge to the panel's centre (the
# edge is uniform, so the move is seamless), then the panel is centred.
python3 - "$OUT" "$SITE" <<'EOF'
import sys
from PIL import Image

sys.dont_write_bytecode = True
sys.path.insert(0, "apps/app/Scripts")
from publish_image import publish

out, site = sys.argv[1], sys.argv[2]
W, H = 840, 1296
im = Image.open(f"{out}/mac.png").convert("RGBA")
# `screencapture -o` leaves everything outside the window transparent, so the
# window's own shape is the alpha channel — which is both how the popover is
# measured here and what mac-cut.webp carries to the site.
alpha = im.getchannel("A").load()

def row_span(y):
    xs = [x for x in range(im.width) if alpha[x, y] > 8]
    return (min(xs), max(xs)) if xs else None

apex_y = next(y for y in range(im.height) if row_span(y))
panel_top = next(
    y for y in range(apex_y, im.height)
    if (s := row_span(y)) and s[1] - s[0] > im.width * 0.5
)
ax0, ax1 = row_span(apex_y + (panel_top - apex_y) // 2)
p = row_span(min(panel_top + 40, im.height - 1))
panel_cx = (p[0] + p[1]) / 2

pad = 6
box = (ax0 - pad, apex_y, ax1 + pad + 1, panel_top)
arrow = im.crop(box)
im.paste((0, 0, 0, 0), box)
dx = round(panel_cx - (ax0 + ax1 + 1) / 2)
im.paste(arrow, (box[0] + dx, box[1]))

scale = max(W / im.width, H / im.height)
im = im.resize((round(im.width * scale), round(im.height * scale)), Image.LANCZOS)
at = (W // 2 - round(panel_cx * scale), (H - im.height) // 2)

# Two files, one capture. The page hangs the cut-out over its own ground and
# casts a shadow that follows the popover's alpha; mac.webp is the same figure
# flattened onto black, for anywhere a plate is wanted instead of a cut-out.
cut = Image.new("RGBA", (W, H), (0, 0, 0, 0))
cut.paste(im, at)
publish(cut, f"{site}/mac-cut.webp", "WEBP", quality=82, method=6)

canvas = Image.new("RGB", (W, H), (0, 0, 0))
canvas.paste(im, at, im)
publish(canvas, f"{site}/mac.webp", "WEBP", quality=82, method=6)
EOF

# A Debug build shares the push identity with the installed app and has
# clobbered its APNs token by running. Kill it; relaunch the installed app
# afterwards so pushes keep arriving.
pkill -x notifi 2>/dev/null || true
echo "Debug build quit — relaunch your installed notifi so Mac push re-registers."
