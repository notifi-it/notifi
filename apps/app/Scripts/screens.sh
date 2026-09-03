#!/usr/bin/env bash
# Every iOS screenshot the product publishes, from one command: the App Store
# sets (iPhone 6.9" and the mandatory iPad 12.9") into fastlane/screenshots,
# and four device shots into apps/api/public/screens.
#
#   make screens
#
# The captures drive nothing by touch. The app seeds its sample data and opens
# the sample message from launch environment (see shotSetup in
# InboxRootView.swift), so a capture is launch → settle → screenshot. Tapping
# was the flaky half of doing this by hand: a shot taken before a menu closed
# or a row settled looks like a bug in the thing being screenshotted.
#
# The Mac popover shot is `make screens-mac` — a separate command because it
# builds and drives the macOS app.
#
# The images the seeded notifications carry are fetched from notifi.it/demo,
# so a new one has to be deployed before it can appear in a capture. Until it
# is, NOTIFI_DEMO_BASE points the seed at another HTTPS origin that serves the
# same bytes — the pushed branch does:
#
#   NOTIFI_DEMO_BASE=https://raw.githubusercontent.com/notifi-it/notifi/<branch>/apps/api/public/demo make screens
set -euo pipefail

cd "$(dirname "$0")/../../.."

BUNDLE_ID=${BUNDLE_ID:-it.notifi.notifi}
DERIVED=${DERIVED:-/tmp/notifi-derived}
OUT=${OUT:-/tmp/notifi-screens}
SITE=apps/api/public/screens
mkdir -p "$SITE"
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
  xcrun simctl list devices available -j | "${PYTHON:-python3}" -c "
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
# Text size is named too. The simulator keeps whatever the last session set
# (one left the phone on medium), and a set captured a step smaller than the
# committed one differs on every frame while looking right on its own.
for udid in "$PHONE" "$IPAD"; do
  xcrun simctl ui "$udid" content_size large
  xcrun simctl status_bar "$udid" override \
    --time "09:41" \
    --dataNetwork wifi --wifiMode active --wifiBars 3 \
    --cellularMode active --cellularBars 4 \
    --batteryState discharging --batteryLevel 100
done

# An unanswered notification-permission alert belongs to SpringBoard, so it
# outlives relaunches and reinstalls and sits in the middle of every capture
# (a run after a hand launch of the app came back with it on all six iPad
# frames). Restarting SpringBoard clears it; the launches below never raise
# a new one, because SampleData suppresses the request.
for udid in "$PHONE" "$IPAD"; do
  xcrun simctl spawn "$udid" launchctl kickstart -k system/com.apple.SpringBoard >/dev/null 2>&1 || true
done
sleep 5

mkdir -p "$OUT"

# One launch per capture, because the setup runs once at launch and the
# screens differ only in environment. --terminate-running-process makes each
# launch a clean slate.
shoot() { # udid outfile extra-env...
  local udid=$1 outfile=$2; shift 2
  # Terminate, settle, then launch. --terminate-running-process alone can
  # resurrect the app with the PREVIOUS launch's environment (observed: a
  # settings capture that came up as the prior pass's inbox), so the kill
  # must be its own step with a beat in between.
  xcrun simctl terminate "$udid" "$BUNDLE_ID" 2>/dev/null || true
  sleep 1
  local marker
  marker="$(xcrun simctl get_app_container "$udid" "$BUNDLE_ID" data)/Documents/shot-ready"
  rm -f "$marker"
  # -AppleLanguages is read at launch, so the app comes up in LANG's language
  # without touching the simulator's own settings. Capturing every locale off
  # one English boot would ship a Spanish listing showing an English app.
  env "$@" SIMCTL_CHILD_NOTIFI_SAMPLE_DATA=1 SIMCTL_CHILD_NOTIFI_SEED_SAMPLE=1 \
    ${NOTIFI_DEMO_BASE:+SIMCTL_CHILD_NOTIFI_DEMO_BASE="$NOTIFI_DEMO_BASE"} \
    xcrun simctl launch "$udid" "$BUNDLE_ID" \
    -AppleLanguages "($LANG_CODE)" -AppleLocale "$LANG_CODE" >/dev/null
  # Wait for the app to say the screen is up, rather than for a number of
  # seconds. A fixed wait counts from the moment simctl returns, which is when
  # the process was spawned -- on a loaded machine the app can still be drawing
  # a second or two later, and the shot lands early. The marker is written when
  # the requested screen has appeared, and for the detail screen when its image
  # has arrived, which is what the old eight-second guess was standing in for.
  for _ in $(seq 1 80); do
    [ -f "$marker" ] && break
    sleep 0.25
  done
  [ -f "$marker" ] || echo "warning: $outfile captured with no ready marker" >&2
  # iOS 26 fades the home indicator about two seconds after a screen appears
  # and does not bring it back without a swipe. Counted from the marker this is
  # a wait for one known animation, not a guess at how long a launch takes.
  sleep 3
  xcrun simctl io "$udid" screenshot --type=png "$OUT/$outfile" >/dev/null
  echo "$OUT/$outfile"
}

# Appearance is named on every capture, never inherited. The app persists what
# NOTIFI_APPEARANCE sets, so the light settings shot at the end of a run used to
# come back as the first shot of the NEXT run — a whole App Store set in the
# wrong colour scheme, from a script that had not changed.
capture_set() { # udid prefix
  shoot "$1" "$2inbox.png"   SIMCTL_CHILD_NOTIFI_START_TAB=inbox SIMCTL_CHILD_NOTIFI_APPEARANCE=dark
  shoot "$1" "$2detail.png"  SIMCTL_CHILD_NOTIFI_START_TAB=inbox SIMCTL_CHILD_NOTIFI_OPEN_SAMPLE_MESSAGE=1 SIMCTL_CHILD_NOTIFI_APPEARANCE=dark
  shoot "$1" "$2keys.png"    SIMCTL_CHILD_NOTIFI_START_TAB=keys SIMCTL_CHILD_NOTIFI_APPEARANCE=dark
}

# One pass per App Store locale. The pairing of language code to store locale
# is the same table `make gen-copy` uses to write fastlane/metadata.
for pair in "en:en-GB" "es:es-ES" "de:de-DE" "fr:fr-FR" "it:it"; do
  LANG_CODE=${pair%%:*}
  LOCALE=${pair##*:}

  capture_set "$PHONE" ""
  capture_set "$IPAD" "ipad-"

  LOCALE="$LOCALE" SHOTS="$OUT" "${PYTHON:-python3}" apps/app/Scripts/appstore-frames.py
  IPAD=1 LOCALE="$LOCALE" SHOTS="$OUT" "${PYTHON:-python3}" apps/app/Scripts/appstore-frames.py
done

# The website is English only, so its four shots are captured after the loop
# rather than reusing the loop's last pass — which is Italian. Settings is on
# the website but not in the App Store set, so it only exists here.
LANG_CODE=en
capture_set "$PHONE" ""
shoot "$PHONE" "settings.png" SIMCTL_CHILD_NOTIFI_START_TAB=settings \
  SIMCTL_CHILD_NOTIFI_APPEARANCE=light

# The website's four shots: the same phone captures at 2x the size the HTML
# declares (620x1348), cover-cropped the few pixels of aspect difference, as
# lossy webp. 2x because the ground's grain lives at device-pixel scale:
# downscaling to 1x averaged it into flat black, and no webp quality brings
# back what the resize removed. The filenames are what index.html references.
"${PYTHON:-python3}" - "$OUT" "$SITE" <<'EOF'
import sys
from PIL import Image

sys.dont_write_bytecode = True
sys.path.insert(0, "apps/app/Scripts")
from publish_image import publish

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
    publish(im.crop((x, y, x + W, y + H)), f"{site}/{name}.webp",
            "WEBP", quality=80, method=6)
EOF
