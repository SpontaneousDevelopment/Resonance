#!/usr/bin/env bash
# Proves the debug sound reload against a real file swap.
#
# The app is sandboxed and cannot write its own bundle, so the swap happens
# here, from outside, while the app keeps running — which is also what a
# developer actually does: replace a .wav in an editor mid-session.
#
# The test polls, reloading and re-reading the asset until the duration changes.
# tap.wav is a 20ms click; level_up.wav is 539ms. If the reload works, the app
# reports the new duration without being restarted.
set -uo pipefail
cd "$(dirname "$0")/.."

BUNDLE=apps/resonance/build/macos/Build/Products/Debug/resonance.app
ASSETS="$BUNDLE/Contents/Frameworks/App.framework/Resources/flutter_assets/assets/sfx"

pkill -f "Build/Products/Debug/resonance.app" 2>/dev/null || true

LOG=$(mktemp)
( cd apps/resonance && RESONANCE_SOUND_SWAP=1 fvm flutter test integration_test/sound_reload_test.dart -d macos ) > "$LOG" 2>&1 &
TEST=$!

# Wait for the app's own signal that it has loaded the original asset, rather
# than for the process to exist: `pgrep` also matches the build, and swapping
# mid-build put the new file in the bundle before the test ever read the old
# one — which made the run fail for the wrong reason.
ready=0
for _ in $(seq 1 300); do
  if grep -q "sfx loaded assets/sfx/tap.wav" "$LOG" 2>/dev/null; then ready=1; break; fi
  kill -0 $TEST 2>/dev/null || break
  sleep 1
done

if [ "$ready" -ne 1 ]; then
  echo "error: the app never reported loading tap.wav"
  cat "$LOG" | tail -20; kill $TEST 2>/dev/null; rm -f "$LOG"; exit 1
fi

BACKUP=$(mktemp)
cp "$ASSETS/tap.wav" "$BACKUP"
restore() { cp "$BACKUP" "$ASSETS/tap.wav" 2>/dev/null || true; rm -f "$BACKUP"; }
trap restore EXIT

echo "app is running and has loaded the original ($(wc -c < "$ASSETS/tap.wav" | tr -d ' ') bytes)"
cp "$ASSETS/level_up.wav" "$ASSETS/tap.wav"
echo "swapped in level_up.wav ($(wc -c < "$ASSETS/tap.wav" | tr -d ' ') bytes) — app still running"

wait $TEST
STATUS=$?
grep -E "sfx loaded|All tests passed|Some tests failed|Expected|reason:" "$LOG" | tail -12
rm -f "$LOG"
exit $STATUS
