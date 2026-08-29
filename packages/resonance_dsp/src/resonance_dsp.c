#include "resonance_dsp.h"

#include <math.h>
#include <stddef.h>

// Vocal range bounds. Human speech fundamentals essentially never fall outside
// this, and constraining the YIN search both speeds it up and removes a whole
// class of octave errors — the most common failure mode of naive pitch
// tracking, where a strong second harmonic reads as the fundamental.
#define RES_MIN_PITCH_HZ 60.0f
#define RES_MAX_PITCH_HZ 500.0f

// YIN searches well above the vocal range and the result is range-checked
// afterwards, rather than the search being restricted to the range.
//
// The difference matters. A periodic signal is periodic at every multiple of
// its period, so starting the search at the 500 Hz lag makes a 1200 Hz tone
// land on 400 Hz — a real period of that signal, reported with full confidence,
// and completely wrong. Searching from 2 kHz down finds the true fundamental
// first, and anything outside the vocal range is then honestly rejected.
#define RES_SEARCH_MAX_HZ 2000.0f

#define RES_DB_FLOOR (-100.0f)
#define RES_CLIP_THRESHOLD 0.999f

// How far above the measured noise floor a frame must sit to count as voice.
// Six dB is roughly where a quiet room stops being ambiguous.
#define RES_VOICING_MARGIN_DB 6.0f

float res_to_db(float linear) {
  if (linear <= 1e-10f) return RES_DB_FLOOR;
  float db = 20.0f * log10f(linear);
  return db < RES_DB_FLOOR ? RES_DB_FLOOR : db;
}

float res_rms(const float *samples, int32_t sample_count) {
  if (samples == NULL || sample_count <= 0) return 0.0f;
  double sum = 0.0;
  for (int32_t i = 0; i < sample_count; i++) {
    const double s = (double)samples[i];
    sum += s * s;
  }
  return (float)sqrt(sum / (double)sample_count);
}

float res_pitch_yin(const float *samples, int32_t sample_count,
                    int32_t sample_rate, float threshold, float *scratch,
                    float *out_confidence) {
  if (out_confidence != NULL) *out_confidence = 0.0f;
  if (samples == NULL || scratch == NULL || sample_count < 128 ||
      sample_rate <= 0) {
    return RES_PITCH_NONE;
  }

  const int32_t half = sample_count / 2;

  int32_t min_tau = (int32_t)(sample_rate / RES_SEARCH_MAX_HZ);
  int32_t max_tau = (int32_t)(sample_rate / RES_MIN_PITCH_HZ);
  if (min_tau < 2) min_tau = 2;
  if (max_tau > half - 1) max_tau = half - 1;
  if (min_tau >= max_tau) return RES_PITCH_NONE;

  // Step 1 — squared difference function.
  for (int32_t tau = 0; tau < half; tau++) {
    scratch[tau] = 0.0f;
  }
  for (int32_t tau = min_tau; tau <= max_tau; tau++) {
    double sum = 0.0;
    const int32_t limit = sample_count - tau;
    for (int32_t i = 0; i < limit; i++) {
      const double delta = (double)samples[i] - (double)samples[i + tau];
      sum += delta * delta;
    }
    scratch[tau] = (float)sum;
  }

  // Step 2 — cumulative mean normalised difference. This is the step that
  // makes YIN robust: it removes the trivial minimum at tau = 0 and normalises
  // away overall level, so a quiet vowel and a loud one score alike.
  double running = 0.0;
  scratch[0] = 1.0f;
  for (int32_t tau = 1; tau < min_tau; tau++) {
    running += (double)scratch[tau];
    scratch[tau] = 1.0f;
  }
  for (int32_t tau = min_tau; tau <= max_tau; tau++) {
    running += (double)scratch[tau];
    scratch[tau] = running > 0.0
                       ? (float)((double)scratch[tau] * (double)tau / running)
                       : 1.0f;
  }

  // Step 3 — absolute threshold. Take the *first* dip below the threshold
  // rather than the global minimum: the first one is the fundamental, the
  // global minimum is often its octave.
  int32_t best_tau = -1;
  for (int32_t tau = min_tau; tau <= max_tau; tau++) {
    if (scratch[tau] < threshold) {
      // Walk to the bottom of this dip.
      while (tau + 1 <= max_tau && scratch[tau + 1] < scratch[tau]) {
        tau++;
      }
      best_tau = tau;
      break;
    }
  }

  // No dip cleared the threshold — fall back to the global minimum so a
  // marginal frame still reports something, but with the low confidence that
  // its aperiodicity earns.
  if (best_tau < 0) {
    float lowest = scratch[min_tau];
    best_tau = min_tau;
    for (int32_t tau = min_tau + 1; tau <= max_tau; tau++) {
      if (scratch[tau] < lowest) {
        lowest = scratch[tau];
        best_tau = tau;
      }
    }
    if (lowest >= 1.0f) return RES_PITCH_NONE;
  }

  // Step 4 — parabolic interpolation around the minimum, for sub-sample
  // precision. Without this, pitch resolution at the top of the vocal range is
  // coarse enough to be visible as stair-stepping in the contour.
  float refined_tau = (float)best_tau;
  if (best_tau > min_tau && best_tau < max_tau) {
    const float a = scratch[best_tau - 1];
    const float b = scratch[best_tau];
    const float c = scratch[best_tau + 1];
    const float denom = 2.0f * (2.0f * b - a - c);
    if (fabsf(denom) > 1e-9f) {
      refined_tau = (float)best_tau + (c - a) / denom;
    }
  }

  if (refined_tau <= 0.0f) return RES_PITCH_NONE;

  const float hz = (float)sample_rate / refined_tau;
  if (hz < RES_MIN_PITCH_HZ || hz > RES_MAX_PITCH_HZ) return RES_PITCH_NONE;

  if (out_confidence != NULL) {
    // Aperiodicity at the chosen lag maps directly to confidence.
    float aperiodicity = scratch[best_tau];
    if (aperiodicity < 0.0f) aperiodicity = 0.0f;
    if (aperiodicity > 1.0f) aperiodicity = 1.0f;
    *out_confidence = 1.0f - aperiodicity;
  }

  return hz;
}

void res_waveform_envelope(const float *samples, int32_t sample_count,
                           int32_t out_count, float *out_min_max) {
  if (out_min_max == NULL || out_count <= 0) return;

  if (samples == NULL || sample_count <= 0) {
    for (int32_t i = 0; i < out_count * 2; i++) out_min_max[i] = 0.0f;
    return;
  }

  for (int32_t bucket = 0; bucket < out_count; bucket++) {
    const int64_t start = ((int64_t)bucket * sample_count) / out_count;
    int64_t end = ((int64_t)(bucket + 1) * sample_count) / out_count;
    if (end <= start) end = start + 1;
    if (end > sample_count) end = sample_count;

    float lo = samples[start];
    float hi = samples[start];
    for (int64_t i = start + 1; i < end; i++) {
      const float s = samples[i];
      if (s < lo) lo = s;
      if (s > hi) hi = s;
    }
    out_min_max[bucket * 2] = lo;
    out_min_max[bucket * 2 + 1] = hi;
  }
}

float res_plosive_score(const float *samples, int32_t sample_count,
                        int32_t sample_rate, float prev_low_energy,
                        float *out_low_energy) {
  if (out_low_energy != NULL) *out_low_energy = 0.0f;
  if (samples == NULL || sample_count <= 1 || sample_rate <= 0) return 0.0f;

  // A one-pole low-pass at ~200 Hz. Cheap, and a steep filter would not make
  // the judgement any better — we are looking for a gross energy imbalance,
  // not measuring a spectrum.
  const float cutoff = 200.0f;
  const float dt = 1.0f / (float)sample_rate;
  const float rc = 1.0f / (2.0f * (float)M_PI * cutoff);
  const float alpha = dt / (rc + dt);

  double low_sum = 0.0;
  double full_sum = 0.0;
  float low = 0.0f;

  for (int32_t i = 0; i < sample_count; i++) {
    low += alpha * (samples[i] - low);
    low_sum += (double)low * (double)low;
    full_sum += (double)samples[i] * (double)samples[i];
  }

  const float low_energy = (float)sqrt(low_sum / (double)sample_count);
  if (out_low_energy != NULL) *out_low_energy = low_energy;

  const float full_energy = (float)sqrt(full_sum / (double)sample_count);
  if (full_energy < 1e-5f) return 0.0f;

  // Two conditions must both hold for a plosive: the frame is dominated by low
  // frequencies, *and* that low energy arrived suddenly. A sustained low note
  // satisfies the first but not the second.
  const float low_ratio = low_energy / full_energy;
  const float onset = prev_low_energy > 1e-6f
                          ? (low_energy - prev_low_energy) / prev_low_energy
                          : (low_energy > 0.02f ? 1.0f : 0.0f);

  if (low_ratio < 0.5f || onset <= 0.0f) return 0.0f;

  float score = low_ratio * (onset > 1.0f ? 1.0f : onset);
  if (score < 0.0f) score = 0.0f;
  if (score > 1.0f) score = 1.0f;
  return score;
}

void res_analyse_frame(const float *samples, int32_t sample_count,
                       int32_t sample_rate, float noise_floor_db,
                       float *scratch, ResFrameAnalysis *out) {
  if (out == NULL) return;

  out->rms = 0.0f;
  out->db = RES_DB_FLOOR;
  out->peak = 0.0f;
  out->pitch_hz = RES_PITCH_NONE;
  out->pitch_confidence = 0.0f;
  out->is_voiced = 0;
  out->is_clipping = 0;

  if (samples == NULL || sample_count <= 0) return;

  float peak = 0.0f;
  for (int32_t i = 0; i < sample_count; i++) {
    const float a = fabsf(samples[i]);
    if (a > peak) peak = a;
  }

  out->rms = res_rms(samples, sample_count);
  out->db = res_to_db(out->rms);
  out->peak = peak;
  out->is_clipping = peak >= RES_CLIP_THRESHOLD ? 1 : 0;

  // Voicing is gated on the room, not on an absolute level. A quiet speaker in
  // a treated room and a loud one in a noisy kitchen should both be judged
  // against their own floor.
  const int voiced_by_level =
      noise_floor_db <= RES_DB_FLOOR
          ? (out->db > -50.0f)
          : (out->db > noise_floor_db + RES_VOICING_MARGIN_DB);

  if (!voiced_by_level) return;

  out->is_voiced = 1;

  // Pitch only runs on frames already judged to contain voice. Running YIN on
  // room tone wastes the frame budget and produces confident nonsense.
  if (scratch != NULL) {
    out->pitch_hz = res_pitch_yin(samples, sample_count, sample_rate, 0.15f,
                                  scratch, &out->pitch_confidence);
  }
}
