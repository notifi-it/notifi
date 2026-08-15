#!/usr/bin/env bash
# Every iOS screenshot the product publishes, from one command: the App Store
# sets (iPhone 6.9" and the mandatory iPad 12.9") into fastlane/screenshots,
# and the four device shots the website shows into apps/api/public/screens.
#
#   make screens
#
# The captures drive nothing by touch. The app seeds its sample data and opens
# the sample message from launch environment (see shotSetup in
# InboxRootView.swift), so a capture is launch → settle → screenshot. Tapping
# was the flaky half of doing this by hand: a shot taken before a menu closed
# or a row settled looks like a bug in the thing being screenshotted.
#
# The Mac popover shot the website also carries is `make screens-mac` — a
# separate command because it builds and drives the macOS app.
set -euo pipefail

cd "$(dirname "$0")/../../.."

BUNDLE_ID=${BUNDLE_ID:-it.notifi.notifi}
DERIVED=${DERIVED:-/tmp/notifi-derived}
OUT=${OUT:-/tmp/notifi-screens}
SITE=apps/api/public/screens
IPAD_NAME="notifi-shots-iPad"
IPAD_TYPE="com.apple.CoreSimulator.SimDeviceType.iPad-Pro-13-inch-M4-8GB"

# The phone half rides on shots.sh: same build-if-stale rule, same booted
# simulator, same DerivedData. Its tab screenshots land in /tmp/notifi-shots
# as a side effect, which is harmless.
TABS="inbox" apps/app/Scripts/shots.sh >/dev/null

APP=$(find "$DERIVED/Build/Products/Debug-iphonesimulator" -maxdepth 1 -name '*.app' | head -1)
[ -n "$APP" ] || { echo "no .app in $DERIVED" >&2; exit 1; }

PHONE=$(xcrun simctl list devices booted -j | python3 -c '
import json,sys
for runtime in json.load(sys.stdin)["devices"].values():
    for d in runtime:
        print(d["udid"]); raise SystemExit
')

IPAD=$(xcrun simctl list devices available -j | python3 -c "
import json,sys
for runtime in json.load(sys.stdin)['devices'].values():
    for d in runtime:
        if d['name'] == '$IPAD_NAME':
            print(d['udid']); raise SystemExit
")
if [ -z "$IPAD" ]; then
  IPAD=$(xcrun simctl create "$IPAD_NAME" "$IPAD_TYPE")
fi
xcrun simctl bootstatus "$IPAD" -b >/dev/null

xcrun simctl install "$IPAD" "$APP"

mkdir -p "$OUT"

# One launch per capture, because the setup runs once at launch and the
# screens differ only in environment. --terminate-running-process makes each
# launch a clean slate.
shoot() { # udid outfile extra-env...
  local udid=$1 outfile=$2; shift 2
  env "$@" SIMCTL_CHILD_NOTIFI_SAMPLE_DATA=1 SIMCTL_CHILD_NOTIFI_SEED_SAMPLE=1 \
    xcrun simctl launch --terminate-running-process "$udid" "$BUNDLE_ID" >/dev/null
  # The detail screen settles slowest: the seeded image arrives over the
  # network, and a shot before it does ships a placeholder.
  case "$outfile" in *detail*) sleep 8 ;; *) sleep 4 ;; esac
  xcrun simctl io "$udid" screenshot --type=png "$OUT/$outfile" >/dev/null
  echo "$OUT/$outfile"
}

capture_set() { # udid prefix
  shoot "$1" "$2inbox.png"   SIMCTL_CHILD_NOTIFI_START_TAB=inbox
  shoot "$1" "$2detail.png"  SIMCTL_CHILD_NOTIFI_START_TAB=inbox SIMCTL_CHILD_NOTIFI_OPEN_SAMPLE_MESSAGE=1
  shoot "$1" "$2keys.png"    SIMCTL_CHILD_NOTIFI_START_TAB=keys
}

capture_set "$PHONE" ""
# Settings is on the website but not in the App Store set.
shoot "$PHONE" "settings.png" SIMCTL_CHILD_NOTIFI_START_TAB=settings
capture_set "$IPAD" "ipad-"

SHOTS="$OUT" python3 apps/app/Scripts/appstore-frames.py
IPAD=1 SHOTS="$OUT" python3 apps/app/Scripts/appstore-frames.py

# The website's four shots: the same phone captures, scaled to the size the
# HTML declares (620x1348) and cover-cropped the few pixels of aspect
# difference, as lossy webp. The filenames are what index.html references.
python3 - "$OUT" "$SITE" <<'EOF'
import sys
from PIL import Image

out, site = sys.argv[1], sys.argv[2]
W, H = 620, 1348
for shot, name in [("inbox", "notifications"), ("detail", "detail"),
                   ("keys", "keys"), ("settings", "settings")]:
    im = Image.open(f"{out}/{shot}.png").convert("RGB")
    scale = max(W / im.width, H / im.height)
    im = im.resize((round(im.width * scale), round(im.height * scale)),
                   Image.LANCZOS)
    x, y = (im.width - W) // 2, (im.height - H) // 2
    # quality=82 smoothed the ground's grain into flat black on the darkest
    # screens; 92 is the lowest setting that keeps it (measured, not guessed).
    im.crop((x, y, x + W, y + H)).save(f"{site}/{name}.webp",
                                       "WEBP", quality=92, method=6)
    print(f"{site}/{name}.webp")
EOF
