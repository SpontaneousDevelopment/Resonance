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

# How long the app may sit with its CPU time not advancing before the run is
# declared frozen rather than slow.
#
# This is the one failure mode the in-test detection cannot catch. A frozen run
# does not fail a threshold — it stops returning, because macOS has suspended
# the process and `tester.pump()` is waiting on a frame that will never arrive.
# The test's own timeout cannot fire either: it is a timer inside the very
# process that has been suspended. So the watchdog has to live out here, and it
# watches the thing that was actually measured — consumed CPU time.
FREEZE_SECONDS=${FREEZE_SECONDS:-90}

# Absolute backstop, mostly for a build that wedges before the app ever starts.
MAX_SECONDS=${MAX_SECONDS:-1200}

run_file() {
  local label="$1"; shift
  echo "=== $label ==="

  "$@" &
  local test_pid=$!
  local waited=0 frozen=0 last_cpu="" still=0

  while kill -0 $test_pid 2>/dev/null; do
    sleep 5
    waited=$((waited + 5))

    local app_pid
    app_pid=$(pgrep -f "Build/Products/Debug/resonance.app/Contents/MacOS" | head -1)
    if [ -n "$app_pid" ]; then
      local cpu
      cpu=$(ps -o time= -p "$app_pid" 2>/dev/null | tr -d ' ')
      if [ -n "$cpu" ] && [ "$cpu" = "$last_cpu" ]; then
        still=$((still + 5))
      else
        still=0
      fi
      last_cpu="$cpu"
      if [ "$still" -ge "$FREEZE_SECONDS" ]; then frozen=1; break; fi
    else
      still=0
    fi

    [ "$waited" -ge "$MAX_SECONDS" ] && break
  done

  if [ "$frozen" -eq 1 ]; then
    echo
    echo "::error::FROZEN — the app consumed no CPU for ${FREEZE_SECONDS}s."
    echo "  This is the environment, not the app. macOS suspended the process"
    echo "  while its window was not being serviced, so no frames arrive and"
    echo "  tester.pump() never returns. Nothing measured here is meaningful."
    echo "  Re-run; see the backgrounded-window note in CLAUDE.md."
    kill $test_pid 2>/dev/null
    pkill -f "Build/Products/Debug/resonance.app" 2>/dev/null || true
    wait $test_pid 2>/dev/null
    return 2
  fi

  if ! kill -0 $test_pid 2>/dev/null; then
    wait $test_pid; return $?
  fi

  echo "::error::TIMEOUT — exceeded ${MAX_SECONDS}s without finishing."
  kill $test_pid 2>/dev/null
  wait $test_pid 2>/dev/null
  return 3
}

failed=0
for file in integration_test/*_test.dart; do
  run_file "$file" fvm flutter test "$file" -d macos "$@" || failed=1
  pkill -f "Build/Products/Debug/resonance.app" 2>/dev/null || true
done

# The telemetry notice behaves differently by build type and both halves matter:
# a test build must show it and be gated by it, a store build must never show it.
# The loop above covers the store case; this covers the other one.
run_file "integration_test/telemetry_notice_test.dart (internal build)" \
  fvm flutter test integration_test/telemetry_notice_test.dart -d macos \
  --dart-define=RESONANCE_INTERNAL_BUILD=true "$@" || failed=1
pkill -f "Build/Products/Debug/resonance.app" 2>/dev/null || true

if [ "$failed" -ne 0 ]; then
  echo
  echo "One or more files failed."
  echo "If it was microphone_test: the mic and speech tests cannot pass from a"
  echo "shell that VS Code is the responsible process for — the OS attributes"
  echo "the TCC request to VS Code and terminates the app. Run this script from"
  echo "Terminal.app instead. See CLAUDE.md."
fi
exit "$failed"
