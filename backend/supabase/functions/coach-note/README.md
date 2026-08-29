# coach-note

Generates the one-line coaching note under an attempt's score.

## What it receives

A transcript and a bundle of numbers. **Never audio.** The recording stays on
the user's device; the numeric score is computed there too. This function exists
only for the qualitative pass, and the feedback screen is complete without it.

## Why it never returns an error status

A missing note is not a failure worth retrying — the score, the component
breakdown and the marked-up script are all already on screen. Returning 500
would invite retry logic around something that is decoration. So failures return
`200` with `{"note": null}` and the client simply doesn't render the card.

## Model

`claude-opus-5` at `effort: low`. A two-sentence note is not a reasoning
problem, and low effort keeps latency inside the window where the note still
feels like part of the same moment as the score.

The system prompt is cached (`cache_control: ephemeral`) — it is byte-identical
on every request, so it is the single largest cost lever here.

**Cost note worth a decision:** at Opus pricing this is roughly a fifth of a
cent per attempt. At one attempt per user per day that is trivial; at the
volume a successful freemium app would see, it is the largest variable cost in
the product and the obvious candidate for the premium-tier boundary ("unlimited
AI feedback passes"). Switching to a cheaper model is a product call, not an
engineering one — say the word and it is a one-line change.

## Deploy

```sh
supabase functions deploy coach-note
supabase secrets set ANTHROPIC_API_KEY=sk-ant-...
```
