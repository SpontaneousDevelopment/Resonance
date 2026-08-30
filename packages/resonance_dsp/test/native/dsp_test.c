// Standalone verification of the DSP core. Not shipped — this exists to prove
// the algorithms behave before any Dart touches them.
#include "resonance_dsp.h"
#include <math.h>
#include <stdio.h>
#include <stdlib.h>

#define SR 48000
#define N 2048

static int failures = 0;

static void check(const char *name, int ok, const char *detail) {
  printf("%s %-46s %s\n", ok ? "  ok " : "FAIL", name, detail ? detail : "");
  if (!ok) failures++;
}

static void fill_sine(float *buf, int n, float hz, float amp, int sr) {
  for (int i = 0; i < n; i++) {
    buf[i] = amp * sinf(2.0f * (float)M_PI * hz * (float)i / (float)sr);
  }
}

// A sawtooth is a much fairer test than a sine: it is rich in harmonics, which
// is exactly what trips naive pitch trackers into octave errors.
static void fill_saw(float *buf, int n, float hz, float amp, int sr) {
  const float period = (float)sr / hz;
  for (int i = 0; i < n; i++) {
    const float phase = fmodf((float)i, period) / period;
    buf[i] = amp * (2.0f * phase - 1.0f);
  }
}

static void fill_noise(float *buf, int n, float amp) {
  unsigned int seed = 12345;
  for (int i = 0; i < n; i++) {
    seed = seed * 1103515245 + 12345;
    const float r = (float)((seed >> 16) & 0x7fff) / 16383.5f - 1.0f;
    buf[i] = amp * r;
  }
}

int main(void) {
  static float buf[N];
  static float scratch[N / 2];
  char detail[128];

  // ── RMS and dB ─────────────────────────────────────────────────────────
  fill_sine(buf, N, 220.0f, 1.0f, SR);
  float rms = res_rms(buf, N);
  snprintf(detail, sizeof detail, "rms=%.4f (expect ~0.7071)", rms);
  check("full-scale sine RMS is 1/sqrt(2)", fabsf(rms - 0.70710678f) < 0.01f, detail);

  check("silence reads as the dB floor", res_to_db(0.0f) <= -100.0f, NULL);
  snprintf(detail, sizeof detail, "db=%.2f", res_to_db(1.0f));
  check("unity amplitude is 0 dBFS", fabsf(res_to_db(1.0f)) < 0.001f, detail);

  // ── Pitch: pure tones across the vocal range ───────────────────────────
  const float tones[] = {80.0f, 110.0f, 147.0f, 220.0f, 330.0f, 440.0f};
  for (int i = 0; i < 6; i++) {
    fill_sine(buf, N, tones[i], 0.8f, SR);
    float conf = 0.0f;
    float hz = res_pitch_yin(buf, N, SR, 0.15f, scratch, &conf);
    const float err = fabsf(hz - tones[i]) / tones[i];
    snprintf(detail, sizeof detail, "want %.0f got %.2f (%.2f%% err, conf %.2f)",
             tones[i], hz, err * 100.0f, conf);
    check("sine pitch within 1%", hz > 0 && err < 0.01f, detail);
  }

  // ── Pitch: harmonic-rich signal, the octave-error trap ─────────────────
  const float saws[] = {98.0f, 165.0f, 262.0f};
  for (int i = 0; i < 3; i++) {
    fill_saw(buf, N, saws[i], 0.6f, SR);
    float conf = 0.0f;
    float hz = res_pitch_yin(buf, N, SR, 0.15f, scratch, &conf);
    const float err = fabsf(hz - saws[i]) / saws[i];
    snprintf(detail, sizeof detail, "want %.0f got %.2f (conf %.2f)", saws[i], hz, conf);
    check("sawtooth: fundamental, not the octave", hz > 0 && err < 0.02f, detail);
  }

  // ── Pitch: rejection ───────────────────────────────────────────────────
  fill_noise(buf, N, 0.5f);
  float conf = 1.0f;
  float hz = res_pitch_yin(buf, N, SR, 0.15f, scratch, &conf);
  snprintf(detail, sizeof detail, "hz=%.2f conf=%.2f", hz, conf);
  check("white noise yields no pitch or low confidence",
        hz == RES_PITCH_NONE || conf < 0.5f, detail);

  fill_sine(buf, N, 1200.0f, 0.8f, SR);
  hz = res_pitch_yin(buf, N, SR, 0.15f, scratch, NULL);
  snprintf(detail, sizeof detail, "hz=%.2f", hz);
  check("above vocal range is rejected", hz == RES_PITCH_NONE, detail);

  fill_sine(buf, N, 30.0f, 0.8f, SR);
  hz = res_pitch_yin(buf, N, SR, 0.15f, scratch, NULL);
  snprintf(detail, sizeof detail, "hz=%.2f", hz);
  check("below vocal range is rejected", hz == RES_PITCH_NONE, detail);

  // ── Confidence is meaningful ───────────────────────────────────────────
  fill_sine(buf, N, 220.0f, 0.8f, SR);
  float clean_conf = 0.0f;
  res_pitch_yin(buf, N, SR, 0.15f, scratch, &clean_conf);
  for (int i = 0; i < N; i++) {
    unsigned int s = (unsigned int)(i * 2654435761u);
    buf[i] += 0.35f * ((float)((s >> 16) & 0x7fff) / 16383.5f - 1.0f);
  }
  float noisy_conf = 0.0f;
  res_pitch_yin(buf, N, SR, 0.15f, scratch, &noisy_conf);
  snprintf(detail, sizeof detail, "clean=%.3f noisy=%.3f", clean_conf, noisy_conf);
  check("confidence drops when the tone is buried", noisy_conf < clean_conf, detail);

  // ── Frame analysis ─────────────────────────────────────────────────────
  ResFrameAnalysis fa;
  fill_sine(buf, N, 220.0f, 0.5f, SR);
  res_analyse_frame(buf, N, SR, -60.0f, scratch, &fa);
  snprintf(detail, sizeof detail, "db=%.1f pitch=%.1f voiced=%d", fa.db, fa.pitch_hz, fa.is_voiced);
  check("loud tone above the floor is voiced with pitch",
        fa.is_voiced && fabsf(fa.pitch_hz - 220.0f) < 3.0f, detail);

  fill_sine(buf, N, 220.0f, 0.0005f, SR);
  res_analyse_frame(buf, N, SR, -60.0f, scratch, &fa);
  snprintf(detail, sizeof detail, "db=%.1f voiced=%d", fa.db, fa.is_voiced);
  check("a signal under the room floor is not voiced", !fa.is_voiced, detail);

  fill_sine(buf, N, 220.0f, 1.0f, SR);
  buf[100] = 1.0f;
  res_analyse_frame(buf, N, SR, -60.0f, scratch, &fa);
  check("full-scale sample sets the clip flag", fa.is_clipping == 1, NULL);

  fill_sine(buf, N, 220.0f, 0.5f, SR);
  res_analyse_frame(buf, N, SR, -60.0f, NULL, &fa);
  check("NULL scratch skips pitch but still meters",
        fa.pitch_hz == RES_PITCH_NONE && fa.is_voiced == 1, NULL);

  // ── Waveform envelope ──────────────────────────────────────────────────
  static float env[64 * 2];
  fill_sine(buf, N, 220.0f, 0.9f, SR);
  res_waveform_envelope(buf, N, 64, env);
  int envelope_ok = 1;
  for (int i = 0; i < 64; i++) {
    if (env[i * 2] > env[i * 2 + 1]) envelope_ok = 0;      // min must be <= max
    if (fabsf(env[i * 2]) > 1.0f || fabsf(env[i * 2 + 1]) > 1.0f) envelope_ok = 0;
  }
  check("envelope buckets are ordered and in range", envelope_ok, NULL);

  res_waveform_envelope(NULL, 0, 8, env);
  int zeroed = 1;
  for (int i = 0; i < 16; i++) if (env[i] != 0.0f) zeroed = 0;
  check("a null buffer yields a flat envelope, not garbage", zeroed, NULL);

  // ── Plosive detection ──────────────────────────────────────────────────
  //
  // These were rewritten after the detector shipped and reported 284 pops a
  // minute on real speech. The original three cases were sine tones compared
  // only against each other — nothing asserted an absolute value against the
  // 0.55 production threshold, and nothing resembled speech. Both gaps are
  // covered below.
  {
    ResPlosiveState st;

    // A speech-like signal: a low fundamental with harmonics and natural
    // frame-to-frame loudness variation. This is the case that was firing
    // continuously — a male fundamental sits below the 200 Hz cutoff, so
    // "the low band dominates" describes an ordinary voice.
    res_plosive_init(&st);
    float worst_speech = 0.0f;
    for (int frame = 0; frame < 40; frame++) {
      // Vary pitch and level the way connected speech does.
      const float f0 = 105.0f + 25.0f * sinf(frame * 0.4f);
      const float level = 0.25f + 0.20f * sinf(frame * 0.7f);
      for (int i = 0; i < N; i++) {
        const float t = (float)(frame * N + i) / SR;
        buf[i] = level * (sinf(2.0f * (float)M_PI * f0 * t) +
                          0.5f * sinf(4.0f * (float)M_PI * f0 * t) +
                          0.25f * sinf(6.0f * (float)M_PI * f0 * t));
      }
      const float s = res_plosive_score(buf, N, SR, &st);
      if (s > worst_speech) worst_speech = s;
    }
    snprintf(detail, sizeof detail, "worst frame %.3f, threshold 0.55",
             worst_speech);
    check("sustained speech never reaches the production threshold",
          worst_speech < 0.55f, detail);

    // A real pop over speech. The speech must be realistic: a pure low sine
    // is almost entirely low-band, which pins the baseline so high that no pop
    // can clear it. Real voiced speech puts substantial energy in formants
    // above the 200 Hz cutoff, so harmonics are what make this a fair test.
    res_plosive_init(&st);
    int qualifying_frames = 0;
    float peak = 0.0f;
    for (int frame = 0; frame < 10; frame++) {
      for (int i = 0; i < N; i++) {
        const float t = (float)(frame * N + i) / SR;
        buf[i] = 0.22f * (sinf(2.0f * (float)M_PI * 110.0f * t) +
                          0.8f * sinf(2.0f * (float)M_PI * 330.0f * t) +
                          0.6f * sinf(2.0f * (float)M_PI * 660.0f * t) +
                          0.3f * sinf(2.0f * (float)M_PI * 1400.0f * t));
        if (frame >= 5) {
          const float since = t - (5.0f * (float)N / (float)SR);
          if (since >= 0.0f) {
            buf[i] += 0.9f * expf(-since / 0.085f) *
                      sinf(2.0f * (float)M_PI * 70.0f * since);
          }
        }
      }
      const float sc = res_plosive_score(buf, N, SR, &st);
      if (sc >= 0.55f) qualifying_frames++;
      if (sc > peak) peak = sc;
    }
    snprintf(detail, sizeof detail, "%d frames qualified, peak %.3f",
             qualifying_frames, peak);
    check("a real pop over speech is detected", qualifying_frames >= 1, detail);
    // The rising baseline suppresses a pop's own decaying tail, so a single pop
    // produces one or two qualifying frames here rather than a long run. On
    // recorded audio three of five injected pops still spanned two frames,
    // which is why the caller debounces — see AttemptScorer.countPlosiveEvents.
    check("a pop does not produce an unbounded run of hits",
          qualifying_frames <= 3, detail);

    // The first frame primes the baseline and must score nothing. A zero
    // previous energy used to be treated as a maximal onset, which made the
    // first frame of every take a false positive.
    {
      ResPlosiveState fresh;
      res_plosive_init(&fresh);
      fill_sine(buf, N, 90.0f, 0.6f, SR);
      const float first = res_plosive_score(buf, N, SR, &fresh);
      snprintf(detail, sizeof detail, "first frame scored %.3f", first);
      check("the priming frame returns exactly zero", first == 0.0f, detail);
    }

    // A sustained low note is not a plosive, however loud. The old test only
    // asserted it scored *lower* than a burst; this asserts it is below the
    // threshold outright.
    res_plosive_init(&st);
    float worst_sustained = 0.0f;
    for (int frame = 0; frame < 20; frame++) {
      fill_sine(buf, N, 80.0f, 0.9f, SR);
      const float s = res_plosive_score(buf, N, SR, &st);
      if (s > worst_sustained) worst_sustained = s;
    }
    snprintf(detail, sizeof detail, "worst %.3f", worst_sustained);
    check("a sustained low note stays below the threshold",
          worst_sustained < 0.55f, detail);

    // Bright content has no low-band energy to burst.
    res_plosive_init(&st);
    for (int frame = 0; frame < 5; frame++) fill_sine(buf, N, 3000.0f, 0.3f, SR);
    float bright = 0.0f;
    for (int frame = 0; frame < 5; frame++) {
      fill_sine(buf, N, 3000.0f, 0.3f, SR);
      const float s = res_plosive_score(buf, N, SR, &st);
      if (s > bright) bright = s;
    }
    snprintf(detail, sizeof detail, "%.3f", bright);
    check("a bright sound never scores as a plosive", bright == 0.0f, detail);

    // Near-silence with a little rumble must not qualify, whatever its shape.
    res_plosive_init(&st);
    float quiet = 0.0f;
    for (int frame = 0; frame < 6; frame++) {
      fill_sine(buf, N, 70.0f, 0.004f, SR);
      const float s = res_plosive_score(buf, N, SR, &st);
      if (s > quiet) quiet = s;
    }
    snprintf(detail, sizeof detail, "%.3f", quiet);
    check("near-silence never scores", quiet == 0.0f, detail);

    // The score must carry information above its minimum — the original
    // collapsed to the low-band ratio for any onset above 1x, so a 24x burst
    // and a 1.01x rise were indistinguishable.
    float small_burst = 0.0f, big_burst = 0.0f;
    for (int pass = 0; pass < 2; pass++) {
      res_plosive_init(&st);
      const float amp = pass == 0 ? 0.14f : 0.85f;
      for (int frame = 0; frame < 5; frame++) {
        const float a = frame == 3 ? amp : 0.04f;
        fill_sine(buf, N, 75.0f, a, SR);
        const float s = res_plosive_score(buf, N, SR, &st);
        if (frame == 3) { if (pass == 0) small_burst = s; else big_burst = s; }
      }
    }
    snprintf(detail, sizeof detail, "small %.3f vs big %.3f", small_burst,
             big_burst);
    check("a bigger burst scores higher than a smaller one",
          big_burst > small_burst, detail);
  }

  // ── Robustness ─────────────────────────────────────────────────────────
  res_analyse_frame(NULL, 0, SR, -60.0f, scratch, &fa);
  check("null input does not crash", fa.rms == 0.0f, NULL);
  check("null scratch pitch call is safe",
        res_pitch_yin(buf, N, SR, 0.15f, NULL, NULL) == RES_PITCH_NONE, NULL);

  printf("\n%s (%d failure%s)\n", failures ? "FAILED" : "all passed",
         failures, failures == 1 ? "" : "s");
  return failures ? 1 : 0;
}
