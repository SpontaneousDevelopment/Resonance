# Resonance

Gamified voice-acting training for iOS, Android and macOS. Full architecture,
curriculum and milestone plan: [`docs/blueprint.html`](docs/blueprint.html).

## Git Workflow

- **Start of every session:** run `git status` and `git pull origin dev` before
  touching anything, to confirm local state matches remote. If they diverge
  unexpectedly, stop and report it rather than working on top of an unknown
  state.
- **Never leave completed, working code uncommitted at the end of a session.**
  If a session ends mid-task, commit a clear WIP checkpoint rather than leaving
  it dangling.
- **Commit in logical units, not one giant dump.** Separate bug fixes, new
  features and test additions into distinct commits, with messages that explain
  *why*, not just *what*.
- **Push to `origin dev` after committing**, so the remote always reflects real
  local state.
- **Before reporting any task "done,"** confirm `git status` is clean and the
  push succeeded.

Committing and pushing completed work is part of finishing a task, not a
separate step to be asked for.

## Toolchain

Flutter is pinned per-project with [fvm](https://fvm.app) — see `.fvmrc`.
**Always invoke it as `fvm flutter ...`**; the machine's global SDK is older and
is shared with unrelated projects.

```sh
fvm flutter pub get                                       # resolves the workspace
fvm dart run tools/curriculum_build/bin/build.dart        # recompile curriculum
fvm flutter analyze && fvm flutter test                   # from apps/resonance
fvm flutter test integration_test/lesson_flow_test.dart -d macos
./tools/verify_plists/verify.sh                           # privacy keys + entitlements
```

## Current State

### Layout

A [pub workspace](https://dart.dev/tools/pub/workspaces) — one lockfile at the
root, several packages beneath it.

| Path | What it is |
| --- | --- |
| `apps/resonance` | The Flutter app. iOS, Android, macOS. |
| `packages/resonance_dsp` | FFI plugin: YIN pitch, RMS/dBFS, voicing, plosive onset, waveform envelope. C core plus Dart bindings. |
| `packages/resonance_models` | **Still the `flutter create` scaffold.** Nothing imports it. Delete or fill it; do not assume it holds anything. |
| `backend/supabase` | Migrations, RLS policies, and the `coach-note` edge function (Deno). |
| `content/curriculum` | Authored curriculum YAML — the source of truth, compiled to a bundled JSON seed. |
| `tools/` | Curriculum compiler, privacy-key verifier. |

Import rules inside the app, in dependency order: `domain/` is pure Dart with no
Flutter import; `core/` may import `domain/` but never `features/`; `features/`
may import anything above; `ui/` is imported by `features/` and imports nothing
from it.

### Milestones

Scoped as M0–M6 for the MVP. See the blueprint for the full plan.

- **M0 — Rails.** Complete. Workspace, three-platform scaffolds, design tokens
  with full light/dark, the mastery ladder, the curriculum compiler (fails the
  build on duplicate ids, dangling prerequisites, cycles), the skill tree, the
  Drift schema, bundled fonts, CI.
- **M1 — Audio spine.** Complete. The DSP plugin, PCM frame re-chunking, the
  semitone-axis live visualiser, and the pre-roll room check. YIN tracks to
  better than 0.05% across 80–440 Hz at ~7% of a 60 fps frame budget.
- **M2 — Score & feedback.** Mostly complete. Word alignment, the scoring
  rubric, the speech-recognition interface, the feedback screen, the lesson
  controller, and the `coach-note` edge function. **Outstanding:** `tools/ingest`
  (licence-checked reference audio) and the coach-rated calibration set that
  tunes the rubric weights.
- **M3–M6.** Progression and persistence, the sensory layer, embed and sync,
  hardening.

Post-MVP (community recordings, leagues, Tier 3 specializations, demo-reel
export, monetization) is deliberately out of scope and unstarted.

### Environment quirks — do not re-investigate

- **VS Code + speech recognition on macOS.** Launching the app from the VS Code
  integrated terminal (`flutter run`, `flutter test -d macos`) makes TCC treat
  **VS Code** as the responsible process. VS Code has no
  `NSSpeechRecognitionUsageDescription`, so TCC kills the app with `SIGABRT` the
  moment it touches `SFSpeechRecognizer` — during the room check. The crash
  message names the plist key regardless of the real reason, which is
  thoroughly misleading. **This is a dev-environment artifact, not an app bug.**
  Proven with a bare Swift probe: identical code aborts from a VS Code shell and
  survives inside a `.app` launched via `open`. Launch via Finder/`open`, or
  grant VS Code Speech Recognition in System Settings. Shipped builds are
  unaffected.
- **Stale build bundles shadow the bundle id.** macOS resolves an identifier
  through LaunchServices, which indexes built bundles anywhere on disk. A leftover
  `build/ios/` bundle predating a plist change will be resolved instead of the
  current app. `tools/verify_plists` checks built bundles for this.
- **Android** needs the SDK command-line tools plus accepted licences, and
  **JDK 21** — Android Gradle Plugin does not support the newer JDKs that may be
  on PATH.
- **`integration_test/microphone_test.dart` is excluded from CI.** Its first
  access raises a modal permission dialog; with nobody to click it the run blocks
  and takes every later test down with it.

### Testing

Six suites: app unit/widget tests, the DSP package's FFI binding tests, a
standalone C harness under `packages/resonance_dsp/test/native` (run it under
`-fsanitize=address,undefined`), integration tests against the real macOS
binary, a Deno type-check of the edge functions, and the privacy-key verifier.

Widget tests cannot build the lesson screen — it constructs the speech
recogniser, which blocks indefinitely with no platform behind it. That path is
covered by `integration_test/` instead.
