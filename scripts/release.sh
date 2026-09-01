#!/usr/bin/env bash
# Builds a distributable Resonance and tells you exactly what is missing.
#
# Everything that can be done without an Apple or Google account is done here.
# Everything that cannot is checked for up front and reported as a list, rather
# than failing halfway through a build or — worse — guessing a value.
#
# Nothing in this script invents a Team ID, a bundle registration, or a keystore.
# Those are account-level facts; a placeholder for any of them produces a build
# that looks signed and is not.
#
# Usage:
#   ./scripts/release.sh ios       # archive + ExportOptions for TestFlight
#   ./scripts/release.sh android   # app bundle for the internal track
#   ./scripts/release.sh macos     # local .app
#   ./scripts/release.sh check     # report readiness and stop
set -uo pipefail
cd "$(dirname "$0")/.."

TARGET="${1:-check}"
APP=apps/resonance

# ── Version scheme ───────────────────────────────────────────────────────────
# pubspec `version: X.Y.Z+N`.
#   X.Y.Z is the marketing version, set by hand when the scope of a release
#         justifies it.
#   N     is the build number, unique and monotonic forever. TestFlight rejects
#         a reused one, so it is derived from the commit count rather than
#         maintained by hand — that is a number nobody has to remember to bump
#         and it cannot go backwards on a fast-forward branch.
MARKETING=$(sed -n 's/^version: \([0-9.]*\)+.*/\1/p' "$APP/pubspec.yaml")
BUILD=$(git rev-list --count HEAD)
echo "Resonance $MARKETING (build $BUILD)"
echo

missing=0
need() { # need <name> <value> <how to get it>
  if [ -z "${2:-}" ]; then
    echo "  MISSING  $1"
    echo "           $3"
    missing=$((missing+1))
  else
    echo "  ok       $1"
  fi
}

echo "Account-level prerequisites:"
case "$TARGET" in
  ios|check)
    need "APPLE_TEAM_ID" "${APPLE_TEAM_ID:-}" \
      "Apple Developer Program membership; Team ID is on the Membership page."
    need "APPLE_BUNDLE_REGISTERED" "${APPLE_BUNDLE_REGISTERED:-}" \
      "Register app.resonance on the developer portal, create the App Store
           Connect record, then set this to 1 to confirm."
    need "APP_STORE_CONNECT_KEY_ID" "${APP_STORE_CONNECT_KEY_ID:-}" \
      "App Store Connect > Users and Access > Integrations > App Store Connect API."
    need "APP_STORE_CONNECT_ISSUER_ID" "${APP_STORE_CONNECT_ISSUER_ID:-}" \
      "Same page as the Key ID."
    need "APP_STORE_CONNECT_KEY_PATH" "${APP_STORE_CONNECT_KEY_PATH:-}" \
      "Path to the .p8, stored OUTSIDE this repository. Never commit it."
    ;;
esac
case "$TARGET" in
  android|check)
    if [ -f "$APP/android/key.properties" ]; then
      echo "  ok       android/key.properties"
    else
      echo "  MISSING  android/key.properties"
      echo "           Create an upload keystore yourself and copy"
      echo "           android/key.properties.example. Not generated here: a"
      echo "           signing key is yours to hold and back up."
      missing=$((missing+1))
    fi
    need "PLAY_SERVICE_ACCOUNT_JSON" "${PLAY_SERVICE_ACCOUNT_JSON:-}" \
      "Play Console > Setup > API access. Path to the JSON, outside the repo."
    ;;
esac

echo
if [ "$TARGET" = "check" ]; then
  [ "$missing" -eq 0 ] && echo "Ready to release." || \
    echo "$missing item(s) blocked on account access. Everything else is wired."
  exit 0
fi

if [ "$missing" -gt 0 ] && [ "$TARGET" != "macos" ]; then
  echo "Cannot build $TARGET: $missing prerequisite(s) missing above."
  echo "These are account-level and cannot be worked around from the codebase."
  exit 1
fi

# ── ExportOptions ────────────────────────────────────────────────────────────
# Generated, never committed, because its only variable content is a Team ID —
# and a committed placeholder Team ID is a build that fails confusingly later.
if [ "$TARGET" = "ios" ]; then
  cat > "$APP/ios/ExportOptions.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>method</key>
	<string>app-store-connect</string>
	<key>teamID</key>
	<string>${APPLE_TEAM_ID}</string>
	<key>uploadSymbols</key>
	<true/>
	<key>destination</key>
	<string>export</string>
</dict>
</plist>
PLIST
  echo "Wrote ios/ExportOptions.plist"
fi

# ── Build ────────────────────────────────────────────────────────────────────
# --split-debug-info keeps release stack traces symbolicable. Without it a
# crash report is a list of hex addresses, which is a crash reporter that
# technically works and tells you nothing.
SYMBOLS="build/symbols/$MARKETING+$BUILD"
COMMON=(--build-name="$MARKETING" --build-number="$BUILD"
        --dart-define=RESONANCE_INTERNAL_BUILD=true
        --split-debug-info="$SYMBOLS" --obfuscate)

case "$TARGET" in
  ios)     (cd "$APP" && fvm flutter build ipa "${COMMON[@]}" \
              --export-options-plist=ios/ExportOptions.plist) ;;
  android) (cd "$APP" && fvm flutter build appbundle "${COMMON[@]}") ;;
  macos)   (cd "$APP" && fvm flutter build macos "${COMMON[@]}") ;;
  *) echo "Unknown target: $TARGET"; exit 1 ;;
esac

echo
echo "Built. Debug symbols in $APP/$SYMBOLS — keep them: without these the"
echo "crash reports from this build cannot be symbolicated."
