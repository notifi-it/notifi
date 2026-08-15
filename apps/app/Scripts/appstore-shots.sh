#!/usr/bin/env bash
# App Store screenshots, end to end: build, capture on an iPhone and an iPad
# simulator, and render both frame sets into fastlane/screenshots/en-GB.
#
#   apps/app/Scripts/appstore-shots.sh        # or: make appstore-shots
#
# The captures drive nothing by touch. The app seeds its sample data and opens
# the sample message from launch environment (see shotSetup in
# InboxRootView.swift), so a capture is launch → settle → screenshot. Tapping
# was the flaky half of doing this by hand: a shot taken before a menu closed
# or a row settled looks like a bug in the thing being screenshotted.
#
# Both sets are mandatory. The iPad set is not a nicety: the app runs on iPad,
# and App Store Connect refuses a submission without ipadPro129 screenshots.
set -euo pipefail

cd "$(dirname "$0")/../../.."

BUNDLE_ID=${BUNDLE_ID:-it.notifi.notifi}
DERIVED=${DERIVED:-/tmp/notifi-derived}
OUT=${OUT:-/tmp/notifi-appstore-shots}
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
capture() { # udid prefix
  local udid=$1 prefix=$2

  SIMCTL_CHILD_NOTIFI_SAMPLE_DATA=1 SIMCTL_CHILD_NOTIFI_SEED_SAMPLE=1 \
  SIMCTL_CHILD_NOTIFI_START_TAB=inbox \
    xcrun simctl launch --terminate-running-process "$udid" "$BUNDLE_ID" >/dev/null
  sleep 5
  xcrun simctl io "$udid" screenshot --type=png "$OUT/${prefix}inbox.png" >/dev/null

  SIMCTL_CHILD_NOTIFI_SAMPLE_DATA=1 SIMCTL_CHILD_NOTIFI_SEED_SAMPLE=1 \
  SIMCTL_CHILD_NOTIFI_START_TAB=inbox SIMCTL_CHILD_NOTIFI_OPEN_SAMPLE_MESSAGE=1 \
    xcrun simctl launch --terminate-running-process "$udid" "$BUNDLE_ID" >/dev/null
  # Longest settle of the three: the seeded image has to arrive over the
  # network before the shot, or the frame ships a placeholder.
  sleep 8
  xcrun simctl io "$udid" screenshot --type=png "$OUT/${prefix}detail.png" >/dev/null

  SIMCTL_CHILD_NOTIFI_SAMPLE_DATA=1 SIMCTL_CHILD_NOTIFI_SEED_SAMPLE=1 \
  SIMCTL_CHILD_NOTIFI_START_TAB=keys \
    xcrun simctl launch --terminate-running-process "$udid" "$BUNDLE_ID" >/dev/null
  sleep 3
  xcrun simctl io "$udid" screenshot --type=png "$OUT/${prefix}keys.png" >/dev/null

  echo "captured ${prefix:-iphone-} set"
}

capture "$PHONE" ""
capture "$IPAD" "ipad-"

SHOTS="$OUT" python3 apps/app/Scripts/appstore-frames.py
IPAD=1 SHOTS="$OUT" python3 apps/app/Scripts/appstore-frames.py
