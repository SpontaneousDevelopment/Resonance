// Generates the one-line coaching note shown under an attempt's score.
//
// Privacy boundary: this function receives a **transcript and numbers**. Audio
// never leaves the device — not to us, not to Anthropic. That is the whole
// reason the qualitative pass is split from the numeric one, and why the
// feedback screen is fully usable when this call fails.
//
// Deploy:
//   supabase functions deploy coach-note
//   supabase secrets set ANTHROPIC_API_KEY=sk-ant-...

import Anthropic from "npm:@anthropic-ai/sdk@^0.122.0";

const client = new Anthropic({
  apiKey: Deno.env.get("ANTHROPIC_API_KEY"),
});

interface CoachNoteRequest {
  lessonTitle: string;
  /** The direction the user was given before recording. */
  brief: string;
  /** What they were meant to say. */
  script: string;
  /** What the recogniser heard. */
  transcript: string;
  metrics: {
    composite: number;
    clarity: number;
    pace: number;
    plosive: number;
    wordsPerMinute: number;
    targetWpmMin?: number;
    targetWpmMax?: number;
  };
  /** Script words that were dropped or misheard, in order. */
  missedWords: string[];
}

const SYSTEM = `You are a voice-acting coach giving one note after a student's take.

Write exactly one or two sentences. No preamble, no score, no lists, no sign-off.

What a good note does:
- Names something specific in THIS take — a word, a moment, a measurable habit.
- Gives one adjustment they can make on the very next attempt.
- Sounds like a person in the room, not a report.

What it never does:
- Repeat the numbers back at them. They can already see the score.
- Praise generically ("great job!"). If the take was good, say what was good and
  what to push next.
- Give more than one adjustment. A student can hold one thing at a time.
- Mention that you are an AI, or that you are working from a transcript.

Good: "You lost the T on 'packed' and 'tight' both times — try landing those
finals a touch harder without slowing down."
Good: "Clean read. Next pass, try dropping your energy slightly on the second
half so the last line has somewhere to go."
Bad: "Your clarity was 78 and your pace was good. Keep practising!"`;

function buildPrompt(request: CoachNoteRequest): string {
  const { metrics: m } = request;
  const paceNote = m.targetWpmMin && m.targetWpmMax
    ? `${Math.round(m.wordsPerMinute)} wpm against a ${m.targetWpmMin}–${m.targetWpmMax} target`
    : `${Math.round(m.wordsPerMinute)} wpm`;

  return [
    `Lesson: ${request.lessonTitle}`,
    `Direction they were given: ${request.brief}`,
    ``,
    `Script:`,
    request.script,
    ``,
    `What was heard:`,
    request.transcript || "(nothing intelligible)",
    ``,
    `Measurements — clarity ${m.clarity}, pace ${m.pace}, plosive control ${m.plosive}.`,
    `Pace: ${paceNote}.`,
    request.missedWords.length > 0
      ? `Words that did not survive: ${request.missedWords.join(", ")}.`
      : `Every word landed.`,
  ].join("\n");
}

Deno.serve(async (req: Request): Promise<Response> => {
  if (req.method !== "POST") {
    return json({ error: "Use POST." }, 405);
  }

  let body: CoachNoteRequest;
  try {
    body = await req.json();
  } catch {
    return json({ error: "Body must be JSON." }, 400);
  }

  if (!body?.script || !body?.metrics) {
    return json({ error: "script and metrics are required." }, 400);
  }

  // Defence in depth: if a future client ever tries to send audio, refuse it
  // here rather than quietly forwarding it.
  if ("audio" in body || "audioBase64" in body) {
    return json({ error: "This endpoint does not accept audio." }, 400);
  }

  try {
    const response = await client.beta.messages.create({
      model: "claude-opus-5",
      max_tokens: 300,
      system: [
        {
          type: "text",
          text: SYSTEM,
          // The system prompt is identical on every request; caching it is the
          // single largest cost lever on this endpoint.
          cache_control: { type: "ephemeral" },
        },
      ],
      // A two-sentence note is not a reasoning problem. Low effort keeps
      // latency and cost down without touching quality here.
      output_config: { effort: "low" },
      betas: ["server-side-fallback-2026-07-01"],
      fallbacks: "default",
      messages: [{ role: "user", content: buildPrompt(body) }],
    });

    if (response.stop_reason === "refusal") {
      // Nothing about a voice drill should trip this, but a refusal must not
      // surface as a broken feedback screen.
      return json({ note: null, reason: "declined" }, 200);
    }

    const note = response.content
      .filter((block) => block.type === "text")
      .map((block) => block.text.trim())
      .join(" ")
      .trim();

    return json({ note: note.length > 0 ? note : null }, 200);
  } catch (error) {
    console.error("coach-note failed:", error);
    // 200 with a null note, deliberately. The client treats a missing note as
    // "no note this time" and shows the score regardless; a 500 would invite
    // retry logic around something that is decoration, not substance.
    return json({ note: null, reason: "unavailable" }, 200);
  }
});

function json(body: unknown, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}
