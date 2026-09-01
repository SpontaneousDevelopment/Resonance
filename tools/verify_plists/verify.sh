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

# ── Privacy manifests ───────────────────────────────────────────────────────
#
# The manifest files were written, reviewed and committed, and did not ship,
# because nothing referenced them: Xcode copies what a target's Resources phase
# lists, not what happens to sit in the folder. That is the wiring-gap pattern
# in Apple build configuration — a component built, correct, and connected to
# nothing.
#
# Checked in two places on purpose. The project reference is checked always,
# because CI runs this before anything is built and a bundle-only check would
# pass vacuously there. The bundle is checked when one exists, because the
# project file states intent and only the bundle is evidence.
for proj in apps/resonance/ios/Runner.xcodeproj apps/resonance/macos/Runner.xcodeproj; do
  pbx="$proj/project.pbxproj"
  if ! grep -q "PrivacyInfo.xcprivacy" "$pbx" 2>/dev/null; then
    echo "error: $pbx does not reference PrivacyInfo.xcprivacy"
    echo "       The manifest will not be copied into the app, and App Store"
    echo "       submission is rejected without one."
    echo "       Fix: ruby tools/xcode/add_privacy_manifest.rb"
    failed=1
  fi
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
# App-root Info.plists at any depth. The previous form used `-maxdepth 6`, which
# excluded macOS entirely — its plist sits seven levels down at
# build/macos/Build/Products/<config>/resonance.app/Contents/Info.plist — so
# this loop had never once examined a macOS bundle, which is the platform the
# stale-bundle problem was found on. It also matched plugin bundles nested
# inside the app, whose identifiers are not app.resonance and were skipped
# anyway.
for bundle in $(find apps/resonance/build -name "Info.plist" \
                  \( -path "*.app/Info.plist" -o -path "*.app/Contents/Info.plist" \) \
                  2>/dev/null); do
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

  # The app's own manifest, not a plugin's — every plugin bundle ships one, so
  # a bare find for the filename would pass on a build missing ours entirely.
  app_root="${bundle%.app/*}.app"
  manifest=""
  for candidate in "$app_root/PrivacyInfo.xcprivacy" \
                   "$app_root/Contents/Resources/PrivacyInfo.xcprivacy"; do
    [[ -f "$candidate" ]] && manifest="$candidate" && break
  done

  if [[ -z "$manifest" ]]; then
    echo "error: a BUILT bundle claiming app.resonance has no privacy manifest:"
    echo "         $app_root"
    echo "       Fix: ruby tools/xcode/add_privacy_manifest.rb, then rebuild."
    failed=1
  elif ! /usr/libexec/PlistBuddy -c "Print :NSPrivacyCollectedDataTypes" \
       "$manifest" 2>/dev/null | grep -q "NSPrivacyCollectedDataTypeCrashData"; then
    # Assert the content, not the filename: a manifest that does not declare
    # what the app actually collects is worse than none, because it reads as a
    # considered answer.
    echo "error: $manifest does not declare crash data collection,"
    echo "       which this app does whenever the user has consented."
    failed=1
  fi
done

if [[ $failed -eq 0 ]]; then
  echo "Info.plist, entitlements, privacy manifests and built bundles: all present."
fi

exit $failed
