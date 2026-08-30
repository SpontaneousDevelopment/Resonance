// Real-time analysis primitives for Resonance.
//
// Everything here runs on raw mono float samples in [-1, 1] and is designed to
// be called once per visualiser frame (~60 Hz) on a background isolate. No
// allocation happens inside the hot functions: the caller owns every buffer.
//
// Why C rather than Dart: YIN pitch detection is O(N^2) in the window size. At
// a 2048-sample window and 60 frames a second that is a few hundred million
// operations per second, which is comfortable in C and is not in Dart.

#ifndef RESONANCE_DSP_H
#define RESONANCE_DSP_H

#include <stdint.h>

#if _WIN32
#define FFI_PLUGIN_EXPORT __declspec(dllexport)
#else
#define FFI_PLUGIN_EXPORT
#endif

#ifdef __cplusplus
extern "C" {
#endif

/// Returned when a frame is unvoiced, too quiet, or otherwise has no usable
/// pitch. Callers must treat this as "no reading", never as a low pitch — the
/// visualiser draws a gap rather than a line to zero.
#define RES_PITCH_NONE (-1.0f)

/// Per-frame analysis result.
typedef struct {
  /// Root-mean-square level of the frame, linear, 0..1.
  float rms;

  /// [rms] expressed in dBFS. Silence clamps to -100 rather than -inf so the
  /// value is always safe to draw and to average.
  float db;

  /// Peak absolute sample in the frame, linear. Used for clip detection, which
  /// RMS alone will miss on a short transient.
  float peak;

  /// Estimated fundamental in Hz, or [RES_PITCH_NONE].
  float pitch_hz;

  /// Confidence in [pitch_hz], 0..1. Derived from the YIN aperiodicity, so a
  /// breathy or creaky frame reports a real number with low confidence rather
  /// than pretending certainty. The UI fades the trace by this value instead of
  /// drawing a confident wrong line.
  float pitch_confidence;

  /// 1 when the frame is judged to contain voice, 0 otherwise.
  int32_t is_voiced;

  /// 1 when any sample in the frame reached digital full scale.
  int32_t is_clipping;
} ResFrameAnalysis;

/// Analyses one frame.
///
/// @param samples      mono float samples in [-1, 1]
/// @param sample_count window length; 1024–4096 is sensible at 44.1/48 kHz
/// @param sample_rate  e.g. 48000
/// @param noise_floor_db the room's measured noise floor, used to gate voicing.
///                       Pass -100 to disable gating.
/// @param scratch      room for `sample_count / 2` floats, owned by the caller
///                     and reused across frames so nothing allocates in the
///                     audio path. Pass NULL to skip pitch detection and get
///                     level and voicing only, which is all the meter needs.
/// @param out          filled on return; never null
FFI_PLUGIN_EXPORT void res_analyse_frame(const float *samples,
                                         int32_t sample_count,
                                         int32_t sample_rate,
                                         float noise_floor_db,
                                         float *scratch,
                                         ResFrameAnalysis *out);

/// Root-mean-square of a buffer, linear.
FFI_PLUGIN_EXPORT float res_rms(const float *samples, int32_t sample_count);

/// Converts a linear amplitude to dBFS, clamped at -100.
FFI_PLUGIN_EXPORT float res_to_db(float linear);

/// Estimates the fundamental frequency using YIN.
///
/// Returns [RES_PITCH_NONE] when no periodicity is found below `threshold`
/// aperiodicity. `out_confidence` may be null.
///
/// `scratch` must have room for `sample_count / 2` floats and is used for the
/// difference function — passed in so the caller can reuse one allocation for
/// the life of a recording rather than allocating per frame.
FFI_PLUGIN_EXPORT float res_pitch_yin(const float *samples,
                                      int32_t sample_count,
                                      int32_t sample_rate,
                                      float threshold,
                                      float *scratch,
                                      float *out_confidence);

/// Downsamples a buffer into `out_count` peak-pairs for waveform drawing.
///
/// Writes `out_count * 2` floats: min then max for each bucket. Drawing from
/// min/max pairs rather than averaged magnitude is what makes a rendered
/// waveform look like the recording instead of a blurred envelope.
FFI_PLUGIN_EXPORT void res_waveform_envelope(const float *samples,
                                             int32_t sample_count,
                                             int32_t out_count,
                                             float *out_min_max);

/// Carries plosive-detector state between frames.
///
/// Three things must persist, and the original version persisted only one:
///
/// * `filter` — the one-pole low-pass state. Resetting it per frame made the
///   filter warm up from silence at every frame boundary, injecting an error
///   of up to 21% into the low-band estimate on real speech.
/// * `baseline` — a slow average of this speaker's normal low-band level. A
///   plosive is a burst above *the speaker's own baseline*; comparing only
///   against the previous frame makes ordinary syllabic loudness variation
///   look like an onset.
/// * `primed` — whether a baseline exists yet. Without it the first frame of
///   every recording was scored as a full-strength onset, which is a
///   guaranteed false positive at the start of every take.
typedef struct {
  float filter;
  float baseline;
  int32_t primed;
} ResPlosiveState;

/// Initialises detector state. Call once per take.
FFI_PLUGIN_EXPORT void res_plosive_init(ResPlosiveState *state);

/// Detects a plosive: a sudden burst of low-frequency energy well above the
/// speaker's own recent level.
///
/// Returns 0 when no plosive is present, and 0.55–1.0 when one is. That lower
/// bound is deliberate and matches the production threshold: a frame meeting
/// every minimum condition scores exactly 0.55, and the score rises with how
/// far past those conditions it goes. A caller comparing against 0.55 is
/// therefore asking "did this qualify at all", which is what the threshold was
/// always meant to mean.
///
/// Three conditions must hold together, calibrated against recorded speech
/// rather than synthetic tones:
///
/// * the low band must clearly dominate (a male fundamental alone does not),
/// * the burst must be several times the speaker's running baseline,
/// * and there must be enough absolute energy to be audible at all.
///
/// `state` must be zero-initialised by [res_plosive_init] before the first
/// frame of a take and passed unchanged thereafter.
FFI_PLUGIN_EXPORT float res_plosive_score(const float *samples,
                                          int32_t sample_count,
                                          int32_t sample_rate,
                                          ResPlosiveState *state);

#ifdef __cplusplus
}
#endif

#endif  // RESONANCE_DSP_H
