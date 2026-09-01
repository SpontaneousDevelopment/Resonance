# Requirements

What Resonance must do, and what must stay true as it changes. Normative only —
this file states rules and current status, never how anything is built (see
[`Design.md`](Design.md)) and never how to work on it (see
[`../CLAUDE.md`](../CLAUDE.md)).

The long-form case for the product — the pedagogy, the skill-tree design, the
content-sourcing position and the risks — is
[`blueprint.html`](blueprint.html). This file is the working spec that argument
produced.

## The product

Gamified voice-acting training for iOS, Android and macOS, taking a beginner to
a professional standard over two to three years. Duolingo-shaped: a skill tree,
short daily lessons, a mastery ladder, streaks.

Capacity is one developer at roughly ten hours a week. Scope decisions assume
that and are not aspirational.

## Product principles

These are load-bearing. Code that violates one is wrong even if it passes its
tests, and a change that erodes one needs an explicit decision, not a patch.

### Practice is never blocked

No hard gate on practising. Vocal Energy is a health signal, not a currency:
running out offers a real ninety-second breathing and humming exercise, always
skippable, and skipping it costs nothing. The reasoning is in the blueprint;
the rule is that nothing in the app may make practice conditional on a meter.

### Anonymous-first, and sign-in is the one deliberate gate

The app is fully usable with no account. Every feature that matters works
signed out, and signing in unlocks nothing that was previously withheld — it
adds sync and nothing else.

**Anonymous auth stays off.** No backend row exists for anyone who has not
asked for one. Silent cloud sync for people who never opted in would be the app
doing something to a user's data as a side effect of something else, which is
exactly what it must not do. Sign-in is therefore also the real conversion
signal — the moment someone chooses a deeper level of investment — and worth
measuring as such rather than blurring.

If merge-vs-adopt at sign-in ever proves annoying in practice, the fix is a
purely local device ID generated at first launch that becomes a one-time
adoption key at sign-in. Not anonymous auth.

### Signing in must never discard local progress

Adoption is automatic only where it cannot lose anything. Anything else is an
explicit user choice. Never resolved by heuristic — not "keep whichever has
more", not "keep whichever is more recent".

### Delete means delete

Delete-my-data removes the server rows, the auth account, and the local
database. Not a soft flag, not a retention window. Confirmation is proportionate
to the irreversibility.

### Recordings stay on the device

No recording leaves the device unless the user asks. If audio upload ever ships it
needs its own consent and its own settings, and must never inherit a control
the user granted for something cheaper — notably the cellular-sync setting,
which governs progress data only.

### Scoring that gates progress happens on-device

The app is fully usable offline. The backend is a filing cabinet, not a
dependency.

### Placeholders ship, and are labelled

Art and sound ship as CC0 placeholders. What is being validated is the *timing*
of feedback, which is the expensive half to get wrong; assets swap later
without touching code. A placeholder is never dressed up as a made decision —
where a product choice has not been made, the UI says so rather than standing
in for it.

### Rubric weights are hand-set, and stay that way for now

Not coach-calibrated. This is an accepted pre-launch gap, **not an outstanding
task**: calibration needs a working voice coach to rate takes against, and
building that relationship is deliberately deferred until the project goes
public.

Do not flag it in milestone audits, and do not produce calibration materials or
tuning work in the meantime — there is nowhere for the output to go, and
hand-tuning weights against intuition would make them *look* calibrated without
being so.

## Curriculum

Four tiers: **Foundations**, **Craft**, **Specializations**, **Mastery &
Industry**. Units within a tier form a prerequisite DAG; the compiler fails the
build on duplicate ids, dangling prerequisites and cycles.

Authored YAML under `content/curriculum` is the source of truth, compiled to a
bundled JSON seed. The MVP authors one unit in full: **Tier 1 Unit 3 —
Articulation & Diction**, five lessons.

### The mastery ladder

| Level | Rank | Score threshold |
| --- | --- | --- |
| Locked | 0 | — |
| Bronze | 1 | 60 |
| Silver | 2 | 70 |
| Gold | 3 | 78 |
| Diamond | 4 | 85 |
| Master | 5 | 90 |

Three rules, all pedagogical rather than technical:

- **One rung at a time.** A score two levels above current promotes by one. A
  lucky take cannot vault someone past material they have not internalised.
- **At most one promotion per lesson per calendar day.** Voice is a motor skill
  and consolidates during sleep; grinding a unit in an evening produces a
  number that does not describe the person's ability.
- **Decay routes review, it does not punish absence.** Levels decay on a
  spacing schedule but never below Bronze once earned.

### Unit gating

A unit opens when its prerequisites reach **Silver across 80% of their
lessons**. Silver rather than Bronze because Bronze is one lucky take and Silver
is evidence of retention. 80% rather than 100% so one stubborn lesson cannot
wall off the curriculum.

Unauthored content cannot gate anything — a unit blocked by lessons nobody has
written yet is indistinguishable from a bug, and is reported as
*not yet authored* rather than as locked.

## Milestones

M0–M6 for the MVP. Scope and current status only; the engineering rationale for
how each was built lives in [`Design.md`](Design.md), and the narrative of how
defects were found lives in git history.

| # | Scope | Status |
| --- | --- | --- |
| **M0** | Rails: workspace, three-platform scaffolds, design tokens with full light/dark, the mastery ladder, the curriculum compiler, the skill tree, the Drift schema, CI. | Complete |
| **M1** | Audio spine: the DSP plugin, PCM frame re-chunking, the semitone-axis live visualiser, the pre-roll room check. | Complete. YIN tracks to better than 0.05% across 80–440 Hz at ~7% of a 60 fps frame budget. |
| **M2** | Score & feedback: word alignment, the scoring rubric, the speech-recognition interface, the feedback screen, the lesson controller, the `coach-note` edge function, `tools/ingest`. | Complete |
| **M3** | Progression: one transaction committing attempt, mastery, XP, streak and energy together; unit gating; Vocal Energy and the rest exercise. | Complete |
| **M4** | Sensory layer: haptics across three platforms, a CC0 sound palette, celebration choreography, a full reduced-motion path. | Complete, including three post-ship defects |
| **M5** | Embed & sync: the listen-and-analyse lesson on the embedded player with in/out points, optional account, outbox sync on reconnect, delete-my-data. | Complete — see below |
| **M6** | Hardening: performance pass, crash reporting, analytics, accessibility audit including VoiceOver on the lesson runner, TestFlight and internal track. | **Partly complete** — see below |

### M5 — what is live-verified

Live on the linked Supabase project: the progress schema, RLS, and
`delete-account`. Verified against a real stack rather than assumed —

- Attempts and progress insert, read back, do not duplicate on retry, and are
  invisible to a second user.
- Deletion is proven end to end from a genuine magic-link session: afterwards
  the rows are gone, the account is gone, and the surviving token can neither
  read nor write.

Two things M5 does **not** claim:

- The sync scheduler's triggers are tested against a real database but a faked
  transport. The full chain from a reconnect to a live row has not been
  exercised in one run.
- `integration_test/` cannot go fully green from a VS Code shell.

### M6 — what is done, and what is blocked

| Component | Status |
| --- | --- |
| M6.1 Performance | Complete. Frame budget asserted in C; three wall-clock guards over the painted paths. |
| M6.2 Crash reporting | Complete. Sentry, hard-configured, gated on informed consent. |
| M6.3 Analytics | Complete as scoped — deferred to post-MVP; sign-in conversion counted locally only. |
| M6.4 Accessibility | Complete. Found and fixed three real defects. |
| M6.5 Distribution | **Blocked on account access.** Everything not requiring an account is wired. |

**Blocked on the account holder** — none of these can be done from the
codebase, and none has been guessed at or given a placeholder:

- Apple Developer Program enrolment, and the Team ID it yields
- `app.resonance` registered on the developer portal, with an App Store Connect
  record
- An App Store Connect API key: Issuer ID, Key ID, and the `.p8`, stored outside
  this repository
- Export compliance declaration and age rating
- A Play Console account, an upload keystore created and held by the developer,
  and a Play service-account JSON
- Sentry project settings: **"Prevent Storing of IP Addresses"**, which is
  server-side and cannot be enforced by the client

`./scripts/release.sh check` reports exactly which of these are missing.

**Also outstanding, and not account-blocked:** the `PrivacyInfo.xcprivacy`
manifests exist for iOS and macOS but are not yet referenced by their Xcode
targets, so they would not ship. Adding them to the Resources build phase is
required before any store submission.

### Deliberate gaps, not outstanding work

- **Rubric calibration** — see the principle above.
- **The embed lesson's clip** is an unmade product choice. The UI renders an
  awaiting-selection state; no placeholder `video_id` stands in for it.

## Out of scope

Community recordings, leagues, daily quests, Tier 3 specializations, demo-reel
export and monetization are post-MVP and unstarted. `features/quests`,
`features/streaks`, `features/profile` and `features/onboarding` are empty
directories, not partial work.
