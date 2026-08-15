#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../../.."

BUNDLE_ID=${BUNDLE_ID:-it.notifi.notifi}
DEVICE=${DEVICE:-iPhone 17 Pro}
TABS=${TABS:-inbox keys settings}
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

APP=$(find "$DERIVED/Build/Products/Debug-iphonesimulator" -maxdepth 1 -name '*.app' 2>/dev/null | head -1)
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
xcrun simctl install "$UDID" "$APP"

mkdir -p "$OUT"
for tab in $TABS; do
  SIMCTL_CHILD_NOTIFI_START_TAB=$tab SIMCTL_CHILD_NOTIFI_SAMPLE_DATA=1 \
    xcrun simctl launch --terminate-running-process \
    "$UDID" "$BUNDLE_ID" >/dev/null
  sleep 2
  xcrun simctl io "$UDID" screenshot --type=png "$OUT/$tab.png" >/dev/null 2>&1
  echo "$OUT/$tab.png"
done
