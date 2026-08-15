#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."
ROOT="$PWD"

export LANG="${LANG:-en_US.UTF-8}"
export LANGUAGE="${LANGUAGE:-en_US.UTF-8}"
export LC_ALL="${LC_ALL:-en_US.UTF-8}"

if [[ -f "$ROOT/.deploy.env" ]]; then
  set -a
  source "$ROOT/.deploy.env"
  set +a
fi

die() { echo "error: $*" >&2; exit 1; }

KEYCHAIN_SVC="${KEYCHAIN_SVC:-notifi-release}"
keychain_get() { security find-generic-password -w -s "$KEYCHAIN_SVC" -a "$1" 2>/dev/null || true; }
: "${ASC_KEY_ID:=$(keychain_get asc-key-id)}"
: "${ASC_ISSUER_ID:=$(keychain_get asc-issuer-id)}"

[[ -n "${ASC_KEY_ID:-}" ]] || die "ASC_KEY_ID is not set. Add it to the Keychain (service $KEYCHAIN_SVC) or apps/app/.deploy.env."
[[ -n "${ASC_ISSUER_ID:-}" ]] || die "ASC_ISSUER_ID is not set. Add it to the Keychain (service $KEYCHAIN_SVC) or apps/app/.deploy.env."

if [[ -z "${TEAM_ID:-}" ]]; then
  TEAM_ID="$(security find-identity -v -p codesigning \
    | sed -n 's/.*"Developer ID Application: .*(\([A-Z0-9]\{10\}\))".*/\1/p' | head -1)"
  [[ -n "$TEAM_ID" ]] || die "TEAM_ID is not set and no Developer ID Application identity was found."
fi

if [[ -z "${ASC_KEY_PATH:-}" ]]; then
  for dir in "$HOME/.appstoreconnect/private_keys" "$HOME/private_keys" "$ROOT"; do
    if [[ -f "$dir/AuthKey_${ASC_KEY_ID}.p8" ]]; then
      ASC_KEY_PATH="$dir/AuthKey_${ASC_KEY_ID}.p8"
      break
    fi
  done
fi
[[ -n "${ASC_KEY_PATH:-}" && -f "$ASC_KEY_PATH" ]] \
  || die "App Store Connect key not found. Set ASC_KEY_PATH to your AuthKey_${ASC_KEY_ID}.p8."
ASC_KEY_PATH="$(cd "$(dirname "$ASC_KEY_PATH")" && pwd)/$(basename "$ASC_KEY_PATH")"

export DEVELOPMENT_TEAM="${DEVELOPMENT_TEAM:-$TEAM_ID}"
export TEAM_ID ASC_KEY_ID ASC_ISSUER_ID ASC_KEY_PATH

if [[ "${1:-}" == "preflight" ]]; then
  command -v xcodegen >/dev/null || die "xcodegen not installed. Run: brew install xcodegen"
  bundle exec fastlane --version >/dev/null 2>&1 \
    || die "fastlane not installed -- run 'bundle install' in apps/app."
  security find-identity -v -p codesigning | grep -q "Developer ID Application.*($TEAM_ID)" \
    || die "No 'Developer ID Application' identity for team $TEAM_ID -- 'make app-dmg' cannot sign."
  security find-identity -v -p codesigning | grep -q "Apple Distribution" \
    || die "No 'Apple Distribution' identity in your keychain -- 'make app-testflight' and 'make app-submit' cannot sign."
  echo "team           $TEAM_ID"
  echo "asc key        $ASC_KEY_ID"
  echo "asc key file   $ASC_KEY_PATH"
  echo "preflight OK"
  exit 0
fi

exec "$@"
