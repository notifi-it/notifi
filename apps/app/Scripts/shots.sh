#!/usr/bin/env bash
# Capture one screenshot per tab from a running Simulator.
#
# Verifying a layout change by hand costs a build, an install, a boot and three
# manual taps, and the taps are the part that goes wrong: a screenshot taken
# before the tab bar settles looks like a bug in the change. This does the same
# thing in one command, launching once per tab with NOTIFI_START_TAB rather than
# driving the UI, and reuses a booted device and a fixed DerivedData so the
# second run onwards is an incremental compile.
#
# The build is skipped when nothing under apps/app is newer than the binary it
# last produced. That decision is not left to whoever types the command: a
# forgotten flag screenshots the previous layout, and a screenshot of the wrong
# build is worse than no screenshot, because it looks like an answer.
#
#   apps/app/Scripts/shots.sh               # shoot every tab
#   FORCE_BUILD=1 apps/app/Scripts/shots.sh # rebuild even if nothing changed
#   TABS="inbox settings" apps/app/Scripts/shots.sh
set -euo pipefail

cd "$(dirname "$0")/../../.."

BUNDLE_ID=${BUNDLE_ID:-it.notifi.notifi}
DEVICE=${DEVICE:-iPhone 17 Pro}
TABS=${TABS:-inbox keys settings}
OUT=${OUT:-/tmp/notifi-shots}
DERIVED=${DERIVED:-/tmp/notifi-derived}

# A booted device is reused as-is. Booting is the single most expensive step
# here and nothing about a layout change requires a clean one.
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

# xcodebuild reaches the same conclusion on its own, but takes ~28s to do it,
# which is most of the cost of a run that changes nothing. A mtime comparison
# answers the same question in milliseconds. It is deliberately coarse: any file
# under apps/app counts, including the generated Copy.swift and the project.
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
  # The first frame after launch is the launch screen. There is no signal to
  # wait on from outside the process, so this is a fixed pause; raise it rather
  # than lowering it if a shot ever comes back blank.
  sleep 2
  xcrun simctl io "$UDID" screenshot --type=png "$OUT/$tab.png" >/dev/null 2>&1
  echo "$OUT/$tab.png"
done
