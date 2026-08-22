#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../../.."

BUNDLE_ID=${BUNDLE_ID:-it.notifi.notifi}
DEVICE=${DEVICE:-iPhone 17 Pro}
TABS=${TABS:-inbox keys settings message key}
# Which seeded message the "message" shot opens. 0 is the richest one — long
# body, image, link, key chip — so the detail page is shot with something in
# every part of it rather than a bare title.
MESSAGE_INDEX=${MESSAGE_INDEX:-0}
# Which seeded key the "key" shot opens. 2 is the one with critical alerts on,
# so the toggle is shot in the state the docs point at.
KEY_INDEX=${KEY_INDEX:-2}
OUT=${OUT:-/tmp/notifi-shots}
DERIVED=${DERIVED:-/tmp/notifi-derived}

UDID=$(xcrun simctl list devices booted -j | python3 -c '
import json,sys
for runtime in json.load(sys.stdin)["devices"].values():
    for d in runtime:
        print(d["udid"]); raise SystemExit
')
if [ -z "$UDID" ]; then
  UDID=$(xcrun simctl list devices available -j | python3 -c "
import json,sys
for runtime in json.load(sys.stdin)['devices'].values():
    for d in runtime:
        if d['name'] == '''$DEVICE''':
            print(d['udid']); raise SystemExit
")
  [ -n "$UDID" ] || { echo "no simulator named '$DEVICE'" >&2; exit 1; }
  xcrun simctl boot "$UDID"
  xcrun simctl bootstatus "$UDID"
fi
open -ga Simulator

# `|| true`: with pipefail a missing DerivedData makes find fail, and set -e
# then kills the script before the build that would recreate the directory —
# silently, with no output and exit 1. An absent build is the normal state on a
# clean machine, and after `make screens`, which uses its own derived path.
APP=$(find "$DERIVED/Build/Products/Debug-iphonesimulator" -maxdepth 1 -name '*.app' 2>/dev/null | head -1 || true)
BINARY="$APP/notifi"

if [ "${FORCE_BUILD:-0}" = "1" ] || [ ! -x "$BINARY" ] ||
   [ -n "$(find apps/app packages/copy/src -newer "$BINARY" \
            -not -path '*/.build/*' -not -path '*/xcuserdata/*' -print -quit 2>/dev/null)" ]; then
  xcodebuild -project apps/app/notifi.xcodeproj -scheme notifi-iOS \
    -configuration Debug -destination "id=$UDID" \
    -derivedDataPath "$DERIVED" DEVELOPMENT_TEAM=Z28DW76Y3W \
    build | tail -5
  APP=$(find "$DERIVED/Build/Products/Debug-iphonesimulator" -maxdepth 1 -name '*.app' | head -1)
else
  echo "nothing changed since the last build — reusing it"
fi

[ -n "$APP" ] || { echo "no .app in $DERIVED after building" >&2; exit 1; }
# The notification permission alert belongs to SpringBoard, not the app, so an
# unanswered one outlives both a relaunch and an uninstall, and lands in the
# middle of every shot. Restarting SpringBoard is what clears it. The launches
# below never raise a new one: SampleData suppresses the request.
xcrun simctl spawn "$UDID" launchctl kickstart -k system/com.apple.SpringBoard >/dev/null 2>&1 || true
sleep 5
xcrun simctl install "$UDID" "$APP"

mkdir -p "$OUT"
for tab in $TABS; do
  START_MESSAGE=
  START_KEY=
  case "$tab" in
    message) START_TAB=inbox; START_MESSAGE=$MESSAGE_INDEX ;;
    key) START_TAB=keys; START_KEY=$KEY_INDEX ;;
    *) START_TAB=$tab ;;
  esac
  SIMCTL_CHILD_NOTIFI_START_TAB=$START_TAB \
  SIMCTL_CHILD_NOTIFI_START_MESSAGE=$START_MESSAGE \
  SIMCTL_CHILD_NOTIFI_START_KEY=$START_KEY \
  SIMCTL_CHILD_NOTIFI_SEED_SAMPLE=1 \
  SIMCTL_CHILD_NOTIFI_SAMPLE_DATA=1 \
    xcrun simctl launch --terminate-running-process \
    "$UDID" "$BUNDLE_ID" >/dev/null
  # 2s caught the boot spinner often enough to matter, and a spinner is the one
  # wrong answer that looks like a real screen rather than a failure.
  sleep 4
  xcrun simctl io "$UDID" screenshot --type=png "$OUT/$tab.png" >/dev/null 2>&1
  echo "$OUT/$tab.png"
done
