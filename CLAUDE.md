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
- **M3 — Progression.** Complete. Progress persists: one transaction commits
  the attempt, mastery, XP, streak and energy together, with a rollback test.
  Unit gating requires Silver across 80% of a unit — Bronze is one lucky take,
  Silver is evidence of retention. Vocal Energy never blocks; running out offers
  a real ninety-second breathing and humming exercise, always skippable. The
  outbox is written but deliberately not drained — no sync consumer until there
  is a backend to sync to.
- **M4 — Sensory layer.** Complete. Haptics (macOS is a genuine no-op with no
  substitute, and a test asserts the sound timeline is identical with and
  without haptics so nobody "fixes" it later), a CC0 placeholder sound palette,
  and a choreography kept as pure data so its *timing* is assertable rather than
  just its contents. Ducking uses an idempotent handle released from every exit
  — a bare duck/unduck pair leaked on any path that skipped the second half, and
  the palette outlives the lesson, so the leak was permanent.
- **M5–M6.** Embed and sync, hardening.

Post-MVP (community recordings, leagues, daily quests, Tier 3 specializations,
demo-reel export, monetization) is deliberately out of scope and unstarted —
`features/quests`, `features/streaks`, `features/profile` and
`features/onboarding` are empty directories, not partial work.

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

### Testing detection code

Learned the expensive way. Plosive detection shipped reporting **284 pops a
minute** on real takes while passing every test it had — three synthetic sine
tones that only compared scores against *each other*, never against the
production threshold, and never against anything resembling speech.

Three rules follow from that:

1. **A detector is not tested until it has seen real signal.** Sine tones tell
   you a function computes; they cannot tell you whether it fires on ordinary
   input. `packages/resonance_dsp/test/native/validate_audio.sh` synthesises
   real speech with `say` and measures against it — clean speech as a
   true-negative set, then pops injected at known times as a true-positive set.
   Run it after touching any detector.
2. **Assert absolute values against the real threshold**, not relative
   comparisons. "A pop scores higher than a hum" passes happily while both sit
   above the threshold and everything triggers.
3. **Prefer state that is a pure function of one input.** Two bugs came from
   state re-derived on rebuild or inferred from something incidental: the
   level-up fanfare replayed because it keyed off a rebuild rather than a
   result, and the breather circle shrank through *hold* because its size was
   inferred by string-matching a phase label that had no case for it. Where a
   value can be `f(elapsed)` or `f(phase)`, make it that — it is immune to
   rebuilds and testable against a virtual clock.
4. **Paired acquire/release calls leak.** `duck()`/`unduck()` written as a pair
   leaked on every exit that skipped the second half — dispose, reset, and a
   throw between them. A handle whose release is idempotent, held in one field
   and released from every exit, makes balance structural instead of something
   each new code path must remember.
5. **Newly-wired code has never run, whatever its test count.** `plosiveScores`
   was populated for the first time in M3; before that the score silently
   defaulted to 100 and the whole path was dead. When wiring up a dormant path,
   treat it as unproven regardless of the coverage it appears to have — the
   tests were written against an implementation nothing had exercised.

### Testing

Six suites: app unit/widget tests, the DSP package's FFI binding tests, a
standalone C harness under `packages/resonance_dsp/test/native` (run it under
`-fsanitize=address,undefined`), integration tests against the real macOS
binary, a Deno type-check of the edge functions, and the privacy-key verifier.

Widget tests cannot build the lesson screen — it constructs the speech
recogniser, which blocks indefinitely with no platform behind it. That path is
covered by `integration_test/` instead.
