#!/usr/bin/env bash
# Verifies that every privacy-sensitive API the app touches has a usage
# description in both Apple Info.plists.
#
# This exists because a missing key is not a warning or an exception — macOS and
# iOS terminate the process with SIGABRT the instant the API is touched. There
# is no catch block that helps, and no log beyond a crash report. Exactly that
# happened with NSSpeechRecognitionUsageDescription: the app died the moment the
# user pressed Record, with no Dart error at all.
#
# Run from the repo root.

set -euo pipefail

REQUIRED=(
  # record — microphone capture
  "NSMicrophoneUsageDescription"
  # speech_to_text — SFSpeechRecognizer
  "NSSpeechRecognitionUsageDescription"
)

PLISTS=(
  "apps/resonance/macos/Runner/Info.plist"
  "apps/resonance/ios/Runner/Info.plist"
)

failed=0

for plist in "${PLISTS[@]}"; do
  if [[ ! -f "$plist" ]]; then
    echo "error: missing $plist"
    failed=1
    continue
  fi

  for key in "${REQUIRED[@]}"; do
    if ! /usr/libexec/PlistBuddy -c "Print :$key" "$plist" >/dev/null 2>&1; then
      echo "error: $plist is missing $key"
      echo "       The OS will terminate the app the moment that API is used."
      failed=1
      continue
    fi

    value=$(/usr/libexec/PlistBuddy -c "Print :$key" "$plist")
    if [[ ${#value} -lt 20 ]]; then
      echo "error: $plist has $key but the explanation is too short to be useful"
      echo "       App Review rejects placeholder strings, and users read these."
      failed=1
    fi
  done
done

# The macOS sandbox needs its own entitlements on top of the usage strings.
# The sandbox requires a separate entitlement per privacy-sensitive service.
# The usage description alone is not enough for a sandboxed app.
for entitlement in \
  "com.apple.security.device.audio-input" \
  "com.apple.security.personal-information.speech-recognition" \
  "com.apple.security.network.client"; do
  for config in DebugProfile Release; do
    file="apps/resonance/macos/Runner/${config}.entitlements"
    if ! /usr/libexec/PlistBuddy -c "Print :$entitlement" "$file" >/dev/null 2>&1; then
      echo "error: $file is missing $entitlement"
      failed=1
    fi
  done
done

# ── Built bundles ───────────────────────────────────────────────────────────
#
# Source plists are not enough. macOS resolves a bundle id through
# LaunchServices, which indexes *built* bundles wherever they sit on disk — so a
# stale build from before a key was added keeps claiming the identifier, and TCC
# reads that one. The app then dies on a permission request no matter how
# correct the source plist is.
#
# That is not hypothetical: a leftover iOS build under build/ios/ shadowed the
# macOS app for an entire debugging session.
for bundle in $(find apps/resonance/build -name "Info.plist" -path "*.app/*" -maxdepth 6 2>/dev/null); do
  app_id=$(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "$bundle" 2>/dev/null || echo "")
  [[ "$app_id" == "app.resonance" ]] || continue

  for key in "${REQUIRED[@]}"; do
    if ! /usr/libexec/PlistBuddy -c "Print :$key" "$bundle" >/dev/null 2>&1; then
      echo "error: a BUILT bundle claiming app.resonance is missing $key:"
      echo "         $bundle"
      echo "       LaunchServices may resolve the bundle id to this stale build,"
      echo "       and TCC will kill the app on a permission request."
      echo "       Fix: flutter clean, or delete that build directory."
      failed=1
    fi
  done
done

if [[ $failed -eq 0 ]]; then
  echo "Info.plist, entitlements and built bundles: all required privacy keys present."
fi

exit $failed
