#!/usr/bin/env bash
# Runs the app with the repo's .env turned into --dart-define flags.
#
# Keys are passed at build time rather than bundled as an asset: an asset is
# readable by anyone who unzips the app. The publishable key is client-safe by
# design, but "secrets live in an asset" is a habit that eventually catches a
# real one.
#
#   ./scripts/run_with_env.sh -d macos

set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [[ ! -f "$ROOT/.env" ]]; then
  echo "No .env at the repo root. Copy .env.example and fill it in." >&2
  exit 1
fi

DEFINES=()
while IFS='=' read -r key value; do
  [[ -z "$key" || "$key" == \#* || -z "$value" ]] && continue
  DEFINES+=("--dart-define=$key=$value")
done < "$ROOT/.env"

cd "$ROOT/apps/resonance"
exec fvm flutter run "${DEFINES[@]}" "$@"
