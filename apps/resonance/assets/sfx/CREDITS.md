# UI sound palette

**Status: placeholder slot — the audio files are not yet in the repository.**

Everything above these files is complete: `SoundPalette.assets` maps each cue to
a path, the bus ducks during capture, and the choreography schedules them. A
missing file is caught and logged once per cue rather than breaking a lesson,
so the app runs correctly without them — silently.

## Dropping a pack in

Put eight files here with these exact names. No code change is required.

| File | Cue | Character |
| --- | --- | --- |
| `tap.wav` | Buttons, selection | Very short, near-subliminal |
| `correct.wav` | Passing attempt | Brief confirmation, not applause — this fires many times a session |
| `mistake.wav` | Low-scoring attempt | **Soft.** A nudge, not a buzzer |
| `record_start.wav` | Take begins | Unmistakable without looking; the user is reading a script |
| `record_stop.wav` | Take ends | Distinct from start |
| `streak_save.wav` | A freeze was spent | Warm, not triumphant — the user was caught, not rewarded |
| `level_up.wav` | Mastery promotion | The main celebration |
| `mastery_unlock.wav` | A unit opens | The rarest event in the product |

On the mistake cue specifically: on this app a poor score is as often vocal
fatigue or a harsh grading call as a real error. A sharp error tone would assign
more fault than the score actually means, and it would undercut the Vocal Energy
mechanic, which exists to say *rest*, not *you failed*.

## Licence

Placeholders must be **CC0** so nothing blocks a build or a release while the
real palette is commissioned. Record each file's source below as it is added —
an uncredited asset is one nobody can later verify the licence of.

| File | Source | Licence |
| --- | --- | --- |
| _(none yet)_ | | |
