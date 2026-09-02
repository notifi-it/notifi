#!/usr/bin/env bash
# The Mac popover shot: build the macOS app, open the popover with sample
# data, photograph just that window, and write
# apps/api/public/screens/mac-cut.webp and mac.webp.
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
mkdir -p "$SITE"
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

# Published at the capture's own pixels, cropped to the popover's own edges
# and lossless: index.html declares half the pixel size, so a 2x display
# paints the capture 1:1 and nothing is resampled before the browser. The
# script prints that size; the <img> width and height must match it. The earlier 840-wide lossy file was softer
# twice over — a 0.86 resize, then WebP smearing the ground's grain — and at
# this size lossless is smaller than lossy q90 anyway (337 KB against 403),
# because the grain is noise and noise costs a lossy encoder more.
#
# Before that the figure is squared with the site: the bar draws its bell at
# 50%, but a real capture clamps the popover against the screen edge, so its
# arrow sits off the panel's centre. The arrow is slid along the panel's top
# edge to the panel's centre (the edge is uniform, so the move is seamless),
# then the panel is centred.
python3 - "$OUT" "$SITE" <<'EOF'
import sys
from PIL import Image

sys.dont_write_bytecode = True
sys.path.insert(0, "apps/app/Scripts")
from publish_image import publish

out, site = sys.argv[1], sys.argv[2]
im = Image.open(f"{out}/mac.png").convert("RGBA")
W, H = im.size
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

at = (W // 2 - round(panel_cx), 0)

# Two files, one capture. The page hangs the cut-out over its own ground and
# casts a shadow that follows the popover's alpha; mac.webp is the same figure
# flattened onto black, for anywhere a plate is wanted instead of a cut-out.
cut = Image.new("RGBA", (W, H), (0, 0, 0, 0))
cut.paste(im, at)
cut = cut.crop(cut.getchannel("A").getbbox())
publish(cut, f"{site}/mac-cut.webp", "WEBP", lossless=True, method=6)

canvas = Image.new("RGB", cut.size, (0, 0, 0))
canvas.paste(cut, (0, 0), cut)
publish(canvas, f"{site}/mac.webp", "WEBP", lossless=True, method=6)
print(f"declare in index.html: width={cut.width // 2} height={cut.height // 2}")
EOF

# A Debug build shares the push identity with the installed app and has
# clobbered its APNs token by running. Kill it; relaunch the installed app
# afterwards so pushes keep arriving.
pkill -x notifi 2>/dev/null || true
echo "Debug build quit — relaunch your installed notifi so Mac push re-registers."
