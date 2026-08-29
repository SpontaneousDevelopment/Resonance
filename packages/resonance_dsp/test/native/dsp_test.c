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
  float low_energy = 0.0f;
  fill_sine(buf, N, 3000.0f, 0.3f, SR);      // bright, no low content
  float p_bright = res_plosive_score(buf, N, SR, 0.0f, &low_energy);
  snprintf(detail, sizeof detail, "score=%.3f", p_bright);
  check("a bright sound scores no plosive", p_bright < 0.2f, detail);

  fill_sine(buf, N, 80.0f, 0.9f, SR);        // sudden low-frequency burst
  float p_thump = res_plosive_score(buf, N, SR, 0.001f, &low_energy);
  snprintf(detail, sizeof detail, "score=%.3f", p_thump);
  check("a sudden low burst scores as a plosive", p_thump > 0.4f, detail);

  fill_sine(buf, N, 80.0f, 0.9f, SR);        // same low note, already sustained
  float p_sustained = res_plosive_score(buf, N, SR, low_energy, &low_energy);
  snprintf(detail, sizeof detail, "sustained=%.3f vs burst=%.3f", p_sustained, p_thump);
  check("a sustained low note is not a plosive", p_sustained < p_thump, detail);

  // ── Robustness ─────────────────────────────────────────────────────────
  res_analyse_frame(NULL, 0, SR, -60.0f, scratch, &fa);
  check("null input does not crash", fa.rms == 0.0f, NULL);
  check("null scratch pitch call is safe",
        res_pitch_yin(buf, N, SR, 0.15f, NULL, NULL) == RES_PITCH_NONE, NULL);

  printf("\n%s (%d failure%s)\n", failures ? "FAILED" : "all passed",
         failures, failures == 1 ? "" : "s");
  return failures ? 1 : 0;
}
