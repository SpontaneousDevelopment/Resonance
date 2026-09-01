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
| `LessonUnlockEvaluator` | Which lessons inside a unit are open, and *why* — sequence, unit closed, or waiting on a clip. |
| `ScoredReadRubric` | Metric → score. Pure; no audio types cross into it. |
| `TranscriptAligner` | Word-level alignment of what was said against the script. |
| `SignInDecision` | Adopt remote, adopt local, ask, or nothing to carry. Pure, because "never silently discard progress" is a product rule that deserves a test rather than an implementation detail. |
| `BreathCycle` | `stateAt(elapsed) → BreathState`. A total function of time. |

`Unit.prerequisiteUnitIds` and `gateLevel` existed from M0 with nothing
evaluating them — the tree opened whatever happened to have content.
`UnlockEvaluator` is that rule made real, and it is pure so the gating can be
tested without a database.

**Why lesson unlocking reads `bestScore` rather than `level`.** Mastery decays,
so the current level is not monotonic; the best score a lesson has ever earned
is. Gating the next lesson on the high-water mark is what makes "never re-lock
something already opened" true by construction rather than by a flag somebody
has to remember to set — a lesson opened stays open through a decay, a restored
backup, or a repair that comes back a rung short.

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

## Authoring a lesson

The curriculum is content, but it is not prose — a lesson is a small piece of
instructional design, and the five authored lessons in Articulation & Diction
are the reference. What follows is what makes them teach rather than merely give
someone something to read aloud.

**The test a lesson has to pass.** A script makes the target behaviour
*unavoidable*; a brief makes it *perceptible*; the score makes it *falsifiable*.
Miss any one and the lesson still runs, and still teaches nothing: an
unavoidable target nobody can hear themselves hit is frustrating, a perceptible
one the script does not force is a suggestion, and either without a score is a
warm-up.

### The script forces the behaviour

Build the passage out of words that collapse without the thing being trained,
so a careless read is audibly wrong rather than merely lower-scoring. *The
Middle of the Word* is the clearest case: "particularly probable statistics
regularly deteriorate" cannot be read intelligibly by someone who articulates
word beginnings and endings and lets the middle go, which is exactly the habit
it targets. The plosive script is dense in P/B/T/D/K/G; the sibilance script can
barely be spoken without a dozen S sounds.

A script that merely *permits* the target behaviour is the failure mode. If a
competent read of the passage sounds the same whether or not the user did the
thing, the lesson is measuring something else.

Keep scripts short — two to four sentences, roughly 25–45 words. Length tests
endurance, which is a different lesson.

Scripts are spoken verbatim and scored against, so direction never appears in
one. The compiler warns on phrases that read like coaching for this reason;
coaching belongs in the brief.

### The brief says what to listen for in yourself

Not "read clearly" but the specific perceptual target: *land every P, B, T, D, K
and G cleanly*, *stop each S early and let the vowel carry the line*. The user
has to know what success sounds like from the inside, because they are the only
one in the room.

Two further jobs the existing briefs do, both worth copying:

- **Name the trade-off being scored.** "We score consonant clarity and plosive
  control together, because they pull against each other" tells the user why the
  task is hard, which is the difference between a challenge and a bad score.
- **Price the failure modes against each other.** "Long, hissing S sounds cost
  points; swallowed ones cost more." Now the user knows which way to err.

### Teach by contrast where a single read cannot

Two of the five are built on producing more than one state and hearing the gap,
and it is the strongest shape available:

- *The Tempo Ladder* — the same line slow, conversational and fast, scored on
  the **lowest** clarity of the three. The lesson is not "read clearly", it is
  "your clarity has a floor and here is where it is".
- *The Over-Articulation Dial* — read twice, once over-enunciated and once
  conversational, scored on the **difference**. The point is control, not
  precision: "precision you cannot switch off is a limitation, not a skill".

Reach for this when the skill is a *range* or a *dial* rather than a target.
A single read can prove someone hit a mark; only a contrast can prove they can
move between two on purpose.

### WPM comes from the mechanism, not from habit

The band is a teaching instrument, not metadata. Three patterns are in use:

- **Standard and narrow** (130–165) where pace is not the variable and should
  stay out of the way.
- **Narrower and slower** (120–155, *The Middle of the Word*) where speed hides
  the very thing being trained — rushing a long word conceals its middle.
- **Deliberately wide** (110–210, *The Tempo Ladder*) where varying tempo *is*
  the exercise, so a band that punished the extremes would punish the lesson.

Set the band by asking what the number is doing. A band copied from the last
lesson is a band doing nothing.

### Check the type is one the app can run

`LessonType` declares eight types. The lesson screen dispatches on *phase*, not
type: every unblocked lesson renders the record-and-score view and is scored by
`ScoredReadRubric`, which scores clarity by aligning the transcript against the
script. So today **`scoredRead` is the only type with a working runtime path**,
and `listenAndAnalyse` renders an awaiting-selection state.

Declaring `pitchMatch` or `micTechnique` today would produce a lesson that
routes, renders and scores nonsense — `micTechnique` has no script, so clarity
would align a transcript against an empty string. Author against what runs, and
add the type first if the lesson genuinely needs one that does not exist yet.

### Diagnostic units are not drill units

*Articulation & Diction* drills a skill: each lesson isolates one mechanism and
scores it. *Meet Your Voice* has a different job — it orients someone who has
never recorded themselves, and its lessons are measurements rather than
corrections. The briefs say so explicitly, because a user who reads a baseline
take as a test they can fail will perform to the test and the baseline will be
worthless.

The techniques above still apply. What changes is the framing in the brief and
the choice of what the script makes unavoidable — in a diagnostic unit, that is
usually a habit the user cannot yet hear, rather than a skill they are building.

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

## Telemetry

Crash reporting only. There is no analytics processor, and the one product
signal worth having before launch — how long someone takes to sign in — is two
dates in local storage that are never transmitted.

**Sentry, with its defaults narrowed rather than accepted.** Session tracking is
off: it is on by default and pings on every launch and close, which is an
always-on usage beacon and exactly what this app refuses to do. Input and
navigation breadcrumbs are off, because a trail of what someone tapped is
behavioural analytics arriving under a crash-reporting banner. No screenshots,
no view hierarchy, no PII.

**Consent is two facts, not one.** `enabled` is what the user chose;
`noticeSeen` is whether they were ever told. `maySend` requires both, so the
tester default of "on" sends nothing until the notice has actually been put in
front of someone. The notice is a screen that gates the app, not a line in
release notes — a notice nobody has to acknowledge is the same shape as a cue
that is declared and never reached.

The build type is a compile-time constant, so a store build physically cannot
ship with the tester default. Store builds are off until someone turns them on
in settings.

**Not tied to sign-in.** Sign-in means sync and nothing else. If it also
switched telemetry on it would quietly mean two things, and someone who wanted
their progress on a second device would have agreed to something they were never
asked about.

Sentry is pinned to 9.x: 8.14.2 does not compile against the current Sentry
Cocoa SDK on macOS — `SentryBinaryImageCache has no member 'image'`.

## Distribution

Release builds carry `--split-debug-info` and `--obfuscate`. Without the former
a release crash report is a list of hex addresses, which is a crash reporter
that technically works and tells you nothing; the symbols are written per build
and must be kept.

The build number is `git rev-list --count HEAD` rather than a hand-maintained
field. TestFlight rejects a reused build number, and a number derived from
history cannot go backwards or be forgotten.

**Privacy manifests are wired into the Xcode targets, not merely present.**
`PrivacyInfo.xcprivacy` exists for iOS and macOS and is listed in each Runner
target's Resources phase; `tools/xcode/add_privacy_manifest.rb` adds it
idempotently, using the same library CocoaPods edits projects with rather than
hand-editing `project.pbxproj`. `tools/verify_plists` then checks three things:
that the project references it at all (which holds in CI, where nothing is
built), that a built bundle actually contains the app's own copy rather than
only the ones every plugin ships, and that the copy declares the crash-data
collection the app really performs.

**Nothing here invents an account-level value.** `ExportOptions.plist` is
generated from `APPLE_TEAM_ID` at release time rather than committed, because a
committed placeholder Team ID produces a build that fails confusingly much
later. The Android signing config reads `key.properties` if it exists and falls
back to debug keys with a loud warning if not — the keystore is never generated
by tooling, since a signing key is the developer's to create, hold and back up,
and one a script made is one that has to be rotated.

## Testability seams

The recurring shape: anything that needs hardware, a network or a clock is an
interface with an injectable implementation, so behaviour can be asserted
without the thing itself.

`SpeechRecogniser`, `SyncTransport`, `AudioCapture`, `CueScheduler`, and the
scheduler's connectivity and auth streams are all seams of this kind. They exist
to make assertions possible, not to abstract for its own sake — each one was
added because a real behaviour was otherwise untestable.
