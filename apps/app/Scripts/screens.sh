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
PHONE_NAME="notifi-shots-iPhone"
PHONE_TYPE="com.apple.CoreSimulator.SimDeviceType.iPhone-16-Pro-Max"

# The phone half rides on shots.sh: same build-if-stale rule, same booted
# simulator, same DerivedData. Its tab screenshots land in /tmp/notifi-shots
# as a side effect, which is harmless.
TABS="inbox" apps/app/Scripts/shots.sh >/dev/null

APP=$(find "$DERIVED/Build/Products/Debug-iphonesimulator" -maxdepth 1 -name '*.app' | head -1)
[ -n "$APP" ] || { echo "no .app in $DERIVED" >&2; exit 1; }

named() { # name
  xcrun simctl list devices available -j | python3 -c "
import json,sys
for runtime in json.load(sys.stdin)['devices'].values():
    for d in runtime:
        if d['name'] == '$1':
            print(d['udid']); raise SystemExit
"
}

# Both sets are captured on a device this script owns. Riding on whatever
# happens to be booted gave a 6.3\" phone, whose capture the frame then
# upscaled to the 6.9\" canvas and whose status bar the strip missed.
PHONE=$(named "$PHONE_NAME")
[ -n "$PHONE" ] || PHONE=$(xcrun simctl create "$PHONE_NAME" "$PHONE_TYPE")
xcrun simctl bootstatus "$PHONE" -b >/dev/null
xcrun simctl install "$PHONE" "$APP"

IPAD=$(named "$IPAD_NAME")
[ -n "$IPAD" ] || IPAD=$(xcrun simctl create "$IPAD_NAME" "$IPAD_TYPE")
xcrun simctl bootstatus "$IPAD" -b >/dev/null
xcrun simctl install "$IPAD" "$APP"

# Apple's own 09:41 on a full battery and full bars. Without it the captures
# carry whatever the clock said, and the three frames sit side by side on the
# listing with three different times.
for udid in "$PHONE" "$IPAD"; do
  xcrun simctl status_bar "$udid" override \
    --time "09:41" \
    --dataNetwork wifi --wifiMode active --wifiBars 3 \
    --cellularMode active --cellularBars 4 \
    --batteryState discharging --batteryLevel 100
done

mkdir -p "$OUT"

# One launch per capture, because the setup runs once at launch and the
# screens differ only in environment. --terminate-running-process makes each
# launch a clean slate.
shoot() { # udid outfile extra-env...
  local udid=$1 outfile=$2; shift 2
  # -AppleLanguages is read at launch, so the app comes up in LANG's language
  # without touching the simulator's own settings. Capturing every locale off
  # one English boot would ship a Spanish listing showing an English app.
  env "$@" SIMCTL_CHILD_NOTIFI_SAMPLE_DATA=1 SIMCTL_CHILD_NOTIFI_SEED_SAMPLE=1 \
    xcrun simctl launch --terminate-running-process "$udid" "$BUNDLE_ID" \
    -AppleLanguages "($LANG_CODE)" -AppleLocale "$LANG_CODE" >/dev/null
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

# One pass per App Store locale. The pairing of language code to store locale
# is the same table `make gen-copy` uses to write fastlane/metadata.
for pair in "en:en-GB" "es:es-ES" "de:de-DE" "fr:fr-FR" "it:it"; do
  LANG_CODE=${pair%%:*}
  LOCALE=${pair##*:}

  capture_set "$PHONE" ""
  capture_set "$IPAD" "ipad-"

  LOCALE="$LOCALE" SHOTS="$OUT" python3 apps/app/Scripts/appstore-frames.py
  IPAD=1 LOCALE="$LOCALE" SHOTS="$OUT" python3 apps/app/Scripts/appstore-frames.py
done

# The website is English only, so its four shots are captured after the loop
# rather than reusing the loop's last pass — which is Italian. Settings is on
# the website but not in the App Store set, so it only exists here.
LANG_CODE=en
capture_set "$PHONE" ""
shoot "$PHONE" "settings.png" SIMCTL_CHILD_NOTIFI_START_TAB=settings

# The website's four shots: the same phone captures at 2x the size the HTML
# declares (620x1348), cover-cropped the few pixels of aspect difference, as
# lossy webp. 2x because the ground's grain lives at device-pixel scale:
# downscaling to 1x averaged it into flat black, and no webp quality brings
# back what the resize removed. The filenames are what index.html references.
python3 - "$OUT" "$SITE" <<'EOF'
import sys
from PIL import Image

out, site = sys.argv[1], sys.argv[2]
W, H = 1240, 2696
for shot, name in [("inbox", "notifications"), ("detail", "detail"),
                   ("keys", "keys"), ("settings", "settings")]:
    im = Image.open(f"{out}/{shot}.png").convert("RGB")
    scale = max(W / im.width, H / im.height)
    im = im.resize((round(im.width * scale), round(im.height * scale)),
                   Image.LANCZOS)
    x, y = (im.width - W) // 2, (im.height - H) // 2
    # At 2x the grain sits at pixel scale and survives compression; 80 keeps
    # it fully (measured), and lower only shaves file size by blurring it.
    im.crop((x, y, x + W, y + H)).save(f"{site}/{name}.webp",
                                       "WEBP", quality=80, method=6)
    print(f"{site}/{name}.webp")
EOF
