#!/usr/bin/env bash
# Fails unless a built notifi.app is signed and carries the production push
# entitlement. Without it iOS refuses the app a device token, the app falls back
# to whatever token it saved from an older build, and APNs accepts every push to
# that token and delivers none of them -- so nothing on the server side notices.
# 2.0.8 to 2.0.23 shipped that way: the local archive was unsigned, and the App
# Store export re-signed it with no entitlements at all.
#
# Usage: assert-push-entitlement.sh path/to/notifi.app
set -euo pipefail

die() { echo "error: $*" >&2; exit 1; }

APP="${1:?usage: assert-push-entitlement.sh path/to/notifi.app}"
[[ -d "$APP" ]] || die "$APP does not exist"

if [[ -d "$APP/Contents" ]]; then
  KEY="com.apple.developer.aps-environment"
else
  KEY="aps-environment"
fi

codesign --verify --strict "$APP" 2>/dev/null || die "$APP is not validly signed:
$(codesign -dv "$APP" 2>&1)"

ENTITLEMENTS="$(codesign -d --entitlements - --xml "$APP" 2>/dev/null)"
[[ -n "$ENTITLEMENTS" ]] || die "$APP is signed with no entitlements"

VALUE="$(plutil -extract "${KEY//./\\.}" raw -o - - <<<"$ENTITLEMENTS" 2>/dev/null || true)"
[[ "$VALUE" == "production" ]] || die "$APP has $KEY='${VALUE}', expected 'production'. Push notifications would never arrive."

echo "$(basename "$APP"): signed, $KEY = production"
