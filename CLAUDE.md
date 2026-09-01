# Resonance

Gamified voice-acting training for iOS, Android and macOS.

| Document | Owns |
| --- | --- |
| [`docs/Requirements.md`](docs/Requirements.md) | What the product must do — principles, curriculum, milestone scope and status. |
| [`docs/Design.md`](docs/Design.md) | How it is built — layout, stack, abstractions, schema, auth and sync. |
| [`docs/blueprint.html`](docs/blueprint.html) | The case for the product — pedagogy, the skill-tree design, platform arguments, risks. |

This file owns the operational material: how to work in the repo, what the
environment does that is surprising, and what counts as verified.

@docs/Requirements.md
@docs/Design.md

## Git workflow

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
supabase start                                            # local stack; Mailpit on :54324

fvm flutter analyze && fvm flutter test                   # from apps/resonance
./scripts/integration_test.sh                             # macOS integration tests
./scripts/release.sh check                                # what distribution still needs
./backend/supabase/tests/verify_delete_account.sh         # deletion, end to end, live
./tools/verify_plists/verify.sh                           # privacy keys + entitlements
```

## Environment quirks — do not re-investigate

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
- **The macOS integration suite must run one file per invocation.**
  `flutter test integration_test` launches the files in parallel and two
  instances of one app bundle collide — the second fails with "Unable to start
  the app on the device". `--concurrency=1` does not prevent it; use
  `scripts/integration_test.sh`.
- **A backgrounded macOS window can stall a test run.** macOS pauses an occluded
  window's display link, and `tester.pump()` waits on a frame from it, so a run
  behind a maximised editor stalls rather than fails. The integration tests ask
  the app to pin its window on screen. This mitigation is **unproven** — the
  stall could not be reproduced on demand afterwards.

## Verification

Two rules. They fail in different ways and are checked separately.

### Rule 1 — a component is not done until something real calls it

**A component is not done when it is built and tested. It is done when
something real calls it, and that call site has a test that fails when the
connection is removed.** If the only callers are tests, it is not done.

This has happened **six times, in six unrelated subsystems**, and every test
passed each time:

| Component | Built, tested, and connected to nothing |
| --- | --- |
| The lesson route | `LessonController` was referenced nowhere. Found in a minute of real use. |
| The tap cue | An asset and entries in two registries, with no caller. Silent. |
| Plosive scores | A controller field that was never filled, so every attempt scored pop-free. |
| The breather's reduced motion | A rewrite dropped the branch; nothing called it. |
| `SyncEngine.drain()` | No caller in the app. A signed-in user would have synced nothing, forever. |
| `PrivacyInfo.xcprivacy` | Written, reviewed, committed — and referenced by no Xcode target, so it was copied into no bundle. |

Isolation tests cannot catch this by construction: they supply the caller the
app fails to. **Every milestone audit checks each deliverable against this
explicitly** — name the real call site, and name the test that fails when the
call is removed.

**A "call site" is not only Dart.** The sixth instance was Apple build
configuration: Xcode copies what a target's Resources phase lists, not what
happens to sit in the folder, so a correct committed file shipped in nothing.
Build configuration, asset registries, CI steps and platform project files are
all places a component can be complete and connected to nothing — and all of
them need the same question asked. Where the artefact is what ships, the check
runs against the artefact: `tools/verify_plists` inspects the built `.app`, not
just the project that was supposed to produce it.

### Rule 2 — a check that reports success by the absence of an error proves nothing

Verification has to assert the specific behaviour expected. Three examples of
checks that ran clean and meant nothing:

- The **plosive thresholds** were tested by three sine tones compared only
  against each other, never against the production threshold. It shipped
  reporting 284 pops a minute on speech.
- The **RLS script** reported catastrophic failure against correct policies,
  because `SET LOCAL` outside a transaction is a no-op and the session stayed
  connected as a superuser that bypasses RLS. Had it merely been error-free it
  would have "passed" while proving nothing at all.
- The **persisted-mastery test** asserted that eight rings exist, not that the
  tree reflects stored state. An audit item named after a *concern* is retired
  by any one passing test mentioning it — name them after the component.

Concretely, for any check: assert the value, not that a call returned; assert
against the real threshold, not a relative comparison; assert with two different
inputs, so a constant cannot masquerade as a computation; and confirm the check
*fails* when the behaviour is broken before trusting that it passes.

Coverage does not substitute for either rule. When the breather's reduced-motion
branch was deleted it took its lines with it — nothing was uncovered, the code
was simply doing less. And no cheap mechanical guard exists: flagging source
changes whose tests did not change is easy to write and mostly false positives,
so it gets ignored. Keeping each cross-cutting concern's tests in one file that
names every component subject to it at least makes an absent one visible while
reading.

## Testing

Seven suites: app unit/widget tests, the DSP package's FFI binding tests, a
standalone C harness under `packages/resonance_dsp/test/native` (run it under
`-fsanitize=address,undefined`), integration tests against the real macOS
binary, a Deno type-check of the edge functions, the privacy-key verifier, and
`backend/supabase/tests/` — the RLS checks plus `verify_delete_account.sh`,
which runs the whole deletion path against the local stack from a genuine
magic-link session pulled out of Mailpit.

Widget tests cannot build the lesson screen — it constructs the speech
recogniser, which blocks indefinitely with no platform behind it. That path is
covered by `integration_test/` instead.
