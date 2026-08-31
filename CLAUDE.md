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
fvm dart run tools/ingest/bin/ingest.dart verify          # audio vs manifest
fvm dart run tools/ingest/bin/ingest.dart restore         # fetch audio on a fresh clone
./scripts/run_with_env.sh -d macos                        # run with backend keys from .env

# Backend. Credentials never live in this repo: linking needs only an access
# token (supabase login), and functions read SUPABASE_SERVICE_ROLE_KEY from the
# environment Supabase injects.
cd backend && supabase db push                            # apply migrations
cd backend && supabase functions deploy delete-account
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
| `backend/supabase` | Migrations, RLS policies, tests, and two Deno edge functions (`coach-note`, `delete-account`). Applied to the live project; `supabase/tests/rls_test.sql` asserts what the policies actually do. |
| `content/curriculum` | Authored curriculum YAML — the source of truth, compiled to a bundled JSON seed. |
| `tools/` | Curriculum compiler, privacy-key verifier, licence-checked audio ingestion. |

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
- **M2 — Score & feedback.** Complete. Word alignment, the scoring rubric, the
  speech-recognition interface, the feedback screen, the lesson controller, the
  `coach-note` edge function, and `tools/ingest`.

  **Rubric weights are hand-set, not coach-calibrated.** This is an accepted
  pre-launch gap, not an outstanding task: calibration needs a working voice
  coach to rate takes against, and building that relationship is deliberately
  deferred until the project goes public. Do not flag it in milestone audits,
  and do not produce calibration materials or tuning work in the meantime —
  there is nowhere for the output to go, and hand-tuning weights against
  intuition would make them *look* calibrated without being so.
- **M3 — Progression.** Complete. Progress persists: one transaction commits
  the attempt, mastery, XP, streak and energy together, with a rollback test.
  Unit gating requires Silver across 80% of a unit — Bronze is one lucky take,
  Silver is evidence of retention. Vocal Energy never blocks; running out offers
  a real ninety-second breathing and humming exercise, always skippable. The
  outbox is written but deliberately not drained — no sync consumer until there
  is a backend to sync to.
- **M4 — Sensory layer.** Complete, including the CC0 placeholder palette and
  all three post-ship defects (duck leak, breather desync, unreachable tap
  cue). Haptics (macOS is a genuine no-op with no
  substitute, and a test asserts the sound timeline is identical with and
  without haptics so nobody "fixes" it later), a CC0 placeholder sound palette,
  and a choreography kept as pure data so its *timing* is assertable rather than
  just its contents. Ducking uses an idempotent handle released from every exit
  — a bare duck/unduck pair leaked on any path that skipped the second half, and
  the palette outlives the lesson, so the leak was permanent.
- **M5 — Embed & sync.** Complete. Live on the linked Supabase project: the
  progress schema, RLS, and the `delete-account` function. Sign-in is a magic
  link, in settings rather than onboarding, and gates nothing — it is the one
  deliberate moment a user chooses to let anything reach the server, which is
  why anonymous auth stays off: no backend row exists for anyone who has not
  asked for one. Delete-my-data removes server rows, the auth account, and the
  local database, server first so a failure cannot strand someone with an
  account holding data they were told was gone. The outbox now genuinely
  drains — the engine and transport were both finished and both unreachable
  until the scheduler wired `drain()` to reconnecting, signing in, and finishing
  an attempt. Cellular sync is its own setting, defaulting on, covering progress
  data only; a test guards against audio ever inheriting it. The embed lesson
  type renders an awaiting-selection state because its clip is a product choice
  that has not been made — not a placeholder standing in for one.

  Verified against a real stack rather than assumed: attempts and progress
  insert, read back, do not duplicate on retry, and are invisible to a second
  user; deletion is proven end to end from a genuine magic-link session pulled
  out of Mailpit, after which the rows are gone, the account is gone, and the
  surviving token can neither read nor write. Live verification is what found
  the transport's 403-on-retry bug, where a merging upsert needed an UPDATE
  policy that `attempts` deliberately does not have.

  Two things it does not claim. The scheduler's own triggers are tested against
  a real database but a faked transport, so the full chain from a reconnect to a
  live row has not been exercised in one run. And `integration_test/` cannot go
  fully green from a VS Code shell — see the TCC note above.
- **M6.** Hardening.

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

### Verification

**A check that reports success by the absence of an error proves nothing.**
Verification has to assert the specific behaviour expected. This has cost real
time five separate times in this project, in five disguises:

- The **plosive detector** passed three sine-tone tests that only compared
  scores against each other, never against the production threshold. It shipped
  reporting 284 pops a minute on speech.
- The **tap cue** had an asset, entries in two registries and a documented
  character. Nothing asserted a declared cue is *reachable*, so it had no
  caller and was silent.
- The **breather's reduced motion** was ticked green by a test covering a
  different component that shared the concern's name. An audit item named after
  a concern is retired by any one passing test mentioning it — name them after
  the component.
- The **outbox sync** had a finished engine and a finished, live-verified
  transport, each with its own passing tests, and `drain()` had no caller
  anywhere in the app. A signed-in user would have queued rows forever and
  synced nothing. Correct components prove nothing about the connection between
  them; test the connection.
- The **RLS script** reported catastrophic failure against correct policies,
  because `SET LOCAL` outside a transaction is a no-op and the session stayed
  connected as a superuser that bypasses RLS. Had the run merely been
  error-free it would have "passed" while proving nothing at all.

Reference this rather than restating the anecdotes. Concretely, for any check:
assert the value, not that a call returned; assert against the real threshold,
not a relative comparison; assert with two different inputs, so a constant
cannot masquerade as a computation; and confirm the check *fails* when the
behaviour is broken before trusting that it passes.

Coverage does not substitute for this. When the breather's reduced-motion
branch was deleted it took its lines with it — nothing was uncovered, the code
was simply doing less. And no cheap mechanical guard exists: flagging source
changes whose tests did not change is easy to write and mostly false positives,
so it gets ignored. Keeping each cross-cutting concern's tests in one file that
names every component subject to it at least makes an absent one visible while
reading.

### Testing

Seven suites: app unit/widget tests, the DSP package's FFI binding tests, a
standalone C harness under `packages/resonance_dsp/test/native` (run it under
`-fsanitize=address,undefined`), integration tests against the real macOS
binary, a Deno type-check of the edge functions, the privacy-key verifier, and
`backend/supabase/tests/` — the RLS checks plus `verify_delete_account.sh`,
which runs the whole deletion path against the local stack from a genuine
magic-link session pulled out of Mailpit.

Run the integration tests with `scripts/integration_test.sh`, not
`flutter test integration_test`. The latter launches the files in parallel, and
two instances of one macOS app bundle collide — the second fails with "Unable
to start the app on the device". `--concurrency=1` does not prevent it.

Widget tests cannot build the lesson screen — it constructs the speech
recogniser, which blocks indefinitely with no platform behind it. That path is
covered by `integration_test/` instead.
