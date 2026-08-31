#!/usr/bin/env bash
# Runs the macOS integration tests, one file per invocation.
#
# `fvm flutter test integration_test` launches the test files in parallel, and
# each one launches the same app bundle — two instances of one macOS app, racing
# each other. The second reliably loses:
#
#   Error waiting for a debug connection: The log reader stopped unexpectedly
#   Failed to load ...: Unable to start the app on the device.
#
# `--concurrency=1` does not prevent it; the second suite still starts while the
# first app is alive. Separate invocations do, because the tool tears the app
# down before returning. This is not a way of running less — every file still
# runs, and every assertion in it still has to pass.
#
# Stragglers from an interrupted run cause the same collision, so clear them
# first rather than inheriting them.
set -uo pipefail
cd "$(dirname "$0")/../apps/resonance"

pkill -f "Build/Products/Debug/resonance.app" 2>/dev/null || true

failed=0
for file in integration_test/*_test.dart; do
  echo "=== $file ==="
  if ! fvm flutter test "$file" -d macos "$@"; then
    failed=1
  fi
  pkill -f "Build/Products/Debug/resonance.app" 2>/dev/null || true
done

if [ "$failed" -ne 0 ]; then
  echo
  echo "One or more files failed."
  echo "If it was microphone_test: the mic and speech tests cannot pass from a"
  echo "shell that VS Code is the responsible process for — the OS attributes"
  echo "the TCC request to VS Code and terminates the app. Run this script from"
  echo "Terminal.app instead. See CLAUDE.md."
fi
exit "$failed"
