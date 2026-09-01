# Design

How Resonance is built, and why it has the shape it has.

**Ownership boundary.** [`Requirements.md`](Requirements.md) says what must be
true; this file says how the code arranges itself to make it true.
[`blueprint.html`](blueprint.html) carries the comparative argument for the
big platform choices — Flutter over React Native, Supabase over Firebase — and
this file does not restate it. Where a decision was already argued there, this
file records the consequence for the code and points back rather than
re-arguing. [`../CLAUDE.md`](../CLAUDE.md) owns operational procedure.

Several shapes below exist because a specific trap was hit. Those are called
out, because a shape whose reason is forgotten gets "simplified" back into the
bug it was avoiding.

## Repository layout

A [pub workspace](https://dart.dev/tools/pub/workspaces) — one lockfile at the
root, several packages beneath it. Not Melos.

| Path | What it is |
| --- | --- |
| `apps/resonance` | The Flutter app. iOS, Android, macOS. |
| `packages/resonance_dsp` | FFI plugin: YIN pitch, RMS/dBFS, voicing, plosive onset, waveform envelope. C core plus Dart bindings. |
| `packages/resonance_models` | **Still the `flutter create` scaffold.** Nothing imports it. Delete or fill it; do not assume it holds anything. |
| `backend/supabase` | Migrations, RLS, tests, and two Deno edge functions (`coach-note`, `delete-account`). |
| `content/curriculum` | Authored curriculum YAML — the source of truth, compiled to a bundled JSON seed. |
| `tools/` | Curriculum compiler, privacy-key verifier, licence-checked audio ingestion. |
| `scripts/` | Run-with-env and the integration-test runner. |

### Layering inside the app

Four layers, and the dependency direction is enforced by review rather than
tooling:

```
domain/    pure Dart, no Flutter import
core/      infrastructure; may import domain/, never features/
features/  may import anything above
ui/        design system; imported by features/, imports nothing from it
```

`domain/` being Flutter-free is what makes the pedagogy testable. The mastery
ladder, the unlock rule, the scoring rubric and the breath cycle are all pure
functions over plain data, so the rules that decide a user's progress can be
tested without a database, a widget or a microphone.

## Stack, and what each choice costs the code

**Flutter** — argued in the blueprint. Consequence here: the 60 fps pitch
visualiser and the skill tree are `CustomPainter`s with no bridge between the
audio callback and the paint.

**Drift** for local persistence. Chosen because progress is relational and the
writes are transactional — one finished attempt commits five things at once,
and it must be all or nothing.

**Riverpod 3** for state, **go_router** for navigation, **freezed** for models.
Riverpod's provider graph is also the composition root: the seams that make
things testable (below) are wired by overriding providers, not by a DI
container.

**A C core behind FFI** for DSP rather than Dart. Pitch detection runs per
frame inside a real-time budget; YIN in Dart would not hold ~7% of a 60 fps
frame. The C is deliberately dependency-free and has its own standalone test
harness, so it can be run under `-fsanitize=address,undefined` without a
Flutter toolchain in the way.

**Speech recognition is the platform's**, not a bundled model. `whisper.cpp`
was considered and dropped: shipping a model would add hundreds of megabytes to
an app whose value is elsewhere, and `SFSpeechRecognizer` is already on the
device.

**Supabase** — argued in the blueprint. Consequence here: Row-Level Security is
the authorization model, so the access rules live in SQL next to the tables
rather than in client code that could be bypassed.

## Key abstractions

Roughly in dependency order. Each is listed with what it is responsible for and,
where relevant, the shape it has to hold.

### `domain/` — the rules

| Abstraction | Responsibility |
| --- | --- |
| `MasteryLevel` / `Mastery` | The ladder: thresholds, one-rung-at-a-time promotion, the daily promotion cap, decay that floors at Bronze. |
| `UnlockEvaluator` | Which units are open, and *why* — returning a `LockReason` and the blocking units, so the UI can say "3 more lessons at Silver" rather than showing a bare padlock. |
| `ScoredReadRubric` | Metric → score. Pure; no audio types cross into it. |
| `TranscriptAligner` | Word-level alignment of what was said against the script. |
| `SignInDecision` | Adopt remote, adopt local, ask, or nothing to carry. Pure, because "never silently discard progress" is a product rule that deserves a test rather than an implementation detail. |
| `BreathCycle` | `stateAt(elapsed) → BreathState`. A total function of time. |

`Unit.prerequisiteUnitIds` and `gateLevel` existed from M0 with nothing
evaluating them — the tree opened whatever happened to have content.
`UnlockEvaluator` is that rule made real, and it is pure so the gating can be
tested without a database.

**Why `BreathCycle` is a function of elapsed time.** The breather originally
drove an `AnimatedContainer` whose target was a boolean and whose duration was
the phase length, which meant *hold* animated toward the small size for four
seconds — the circle shrank through the phase it was meant to hold. Size is now
a value the model computes for an instant, and smoothness comes from a ticker
rebuilding every frame. Because everything visible derives from one elapsed
`Duration`, an unrelated rebuild recomputes the same state instead of
restarting an animation mid-cycle.

### `core/` — infrastructure

| Abstraction | Responsibility |
| --- | --- |
| `VoiceAnalyser` (in `resonance_dsp`) | The Dart face of the C core: pitch, RMS/dBFS, voicing, plosive onset, envelope. |
| `RecordingSession` | Owns the platform recorder and emits `FrameAnalysis` frames. |
| `SpeechRecogniser` | Interface over platform STT. Injectable, because the real one cannot exist in a widget test. |
| `AttemptScorer` | Joins take + transcript + frames into a score. Deliberately thin — every judgement lives in `domain/scoring`. |
| `ProgressRepository` | The single write path for a finished attempt. |
| `CurriculumRepository` | Loads the compiled curriculum from the bundle. |
| `SensoryDirector` | Plays a choreographed cue sequence. |
| `SyncEngine` | Drains the outbox, oldest first. |
| `SyncScheduler` | Decides *when* the engine drains. |
| `SupabaseTransport` | Puts outbox rows on the server. |
| `AccountService` | Magic-link sign-in, sign-out, and full deletion. |

### `features/lesson` — the runner

`LessonController` is one state machine parameterised by lesson type, rather
than a controller per type. It emits a `SessionOutcome` — everything one attempt
changed, in one value, so the feedback screen renders from a single call instead
of issuing four reads and hoping they agree.

**The recorder is constructed lazily.** Building a `RecordingSession` opens the
platform recorder, which needs a Flutter binding. Eager construction meant the
controller could not be built at all without the mic stack — and there is no
reason to hold the microphone before the user has asked for anything.

**The controller knows nothing about syncing.** It reports a fact — an attempt
was recorded — through an optional callback, and the caller decides what that is
worth. Nothing waits on it, so a slow network cannot delay the score someone is
waiting to look at.

## Local persistence

Drift, schema version 3. Tables: `LessonProgress`, `Attempts`, `StreakState`,
`DailyXp`, `Outbox`, `EnergyState`.

Migrations are additive only, and the reason is a product rule rather than a
convenience: v1→v2 added the Vocal Energy meter and seeds the new row **full**,
because an upgrade must never hand someone a depleted meter.

**One attempt is one transaction.** The attempt row, the mastery change, the XP,
the streak and the energy commit together or not at all, with a rollback test
asserting exactly that. Progress that is half-written is worse than progress
that failed to write, because the user cannot tell.

**The outbox is written whether or not anyone is signed in.** The rows recorded
before there was an account are the reason sign-in has months of history to send
rather than a gap where the first weeks of use should be.

## Server model

Five tables — `profiles`, `lesson_progress`, `attempts`, `streak_state`,
`daily_xp` — every one keyed on `user_id` referencing `auth.users` with
`on delete cascade`.

**There is no column for a recording.** The absence is the enforcement.

### Authorization

Deny by default, `force row level security` on every table, and every policy
scoped to `(select auth.uid())`. RLS lives in the migrations beside the tables;
`backend/supabase/tests/rls_test.sql` asserts what the policies actually do
rather than that they exist. (`backend/supabase/policies/` is an empty leftover
directory.)

**`attempts` has no UPDATE policy, deliberately.** An attempt is history; it is
written once and never revised. This has a direct consequence for the client —
see the transport below.

### Auth

Magic link only. A password is one more thing to lose, reuse, and be responsible
for storing, and nothing here is worth that. Sign-in lives in settings rather
than onboarding: asking for an email before someone has read a line aloud is
asking them to commit before they know whether they want to.

**Deletion is server-first.** `delete-account` removes the server rows and the
auth account, and only then is the local database wiped. The other order can
strand someone signed into an account holding data they were told was gone, with
no local copy left to retry from. The edge function reads its service-role key
from the environment Supabase injects — no secret is ever written to a file the
app builds from.

A session token outlives the account it belonged to, because a JWT is stateless
and PostgREST honours the signature until it expires. That is safe here, but
only because two separate things are true and both are asserted: the token can
read nothing, and it can write nothing.

## Sync

Four pieces, and the seams between them are where the bugs were.

```
ProgressRepository ──enqueue──> Outbox ──SyncEngine.drain()──> SupabaseTransport
                                            ▲
                                     SyncScheduler
                        (reconnect · sign-in · attempt finished)
```

**`SyncEngine`** sends oldest-first and preserves the outbox's monotonic
sequence. Ordering is the invariant: a mastery promotion arriving before the
attempt that caused it would be rejected by the server's own validation, and the
client would retry it forever.

**Parking is a persisted column, not an in-memory set.** A permanently rejected
row at the head of the queue blocks everything behind it, and an in-memory
poison list forgets on restart — so the same doomed row blocked the queue again
on every launch. Rows the server will never accept are marked parked in the
database and excluded by the query.

**`SyncScheduler`** is the piece that was missing. The engine and the transport
were both finished, both tested, and `drain()` had no caller anywhere in the
app; a signed-in user would have queued rows forever and synced nothing. It now
drains on three triggers, each for a distinct failure:

| Trigger | Prevents |
| --- | --- |
| Reconnecting | Practice done offline never arriving |
| Signing in | The history recorded before an account existed staying local |
| Finishing an attempt | Being a day behind on a second device |

Losing the connection deliberately does *not* trigger a send — queueing a doomed
request behind the ones already waiting helps nobody.

**`SupabaseTransport` uses `ignoreDuplicates`, not a merging upsert.** A merging
upsert requires UPDATE, which `attempts` deliberately does not grant, so every
retry was refused with 403 — found by live verification, not by any unit test.
Ignoring is also the correct semantics: a resend means the first request landed,
not that the record changed.

**Cellular sync is its own setting**, defaulting on, governing progress data
only. It is separated from any future audio-upload behaviour *before* there is
pressure to conflate them, and a test guards the separation.

## Sensory layer

The choreography is **pure data**, so a sequence's *timing* is assertable rather
than only its contents. The director takes an injectable scheduler for the same
reason: a director calling `Future.delayed` directly would be testable for
content and untestable for choreography, which is the half that decides whether
the app feels designed.

**Ducking uses an idempotent handle released from every exit.** A bare
duck/unduck pair leaked on any path that skipped the second half — dispose,
reset, a failed start — and because the sound palette outlives the lesson, the
leak was permanent: an app-scoped bus muted for the rest of the session.
Boundary cues also play *outside* the duck window rather than inside it.

**Reduced motion removes pacing, not feedback.** Every cue still fires, in the
same order, without the choreography between them; a user who cannot see a ring
fill is still told they levelled up.

**macOS haptics are a genuine no-op with no substitute.** A flat macOS
experience is the accepted tradeoff, and a test asserts the sound timeline is
identical with and without haptics so that nobody later "fixes" it by
compensating with extra sound.

## Testability seams

The recurring shape: anything that needs hardware, a network or a clock is an
interface with an injectable implementation, so behaviour can be asserted
without the thing itself.

`SpeechRecogniser`, `SyncTransport`, `AudioCapture`, `CueScheduler`, and the
scheduler's connectivity and auth streams are all seams of this kind. They exist
to make assertions possible, not to abstract for its own sake — each one was
added because a real behaviour was otherwise untestable.
