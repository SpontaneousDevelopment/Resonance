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

/// Detects plosive energy: a sudden burst concentrated below ~200 Hz.
///
/// Returns 0..1, where 0 is clean and 1 is a full thump on the diaphragm.
/// Implemented as the ratio of low-band to broadband energy, weighted by how
/// abruptly the level rose — a steady low note is not a plosive, a sudden one
/// is.
///
/// `prev_low_energy` carries state between frames; pass 0 on the first frame
/// and thereafter the value written to `out_low_energy`.
FFI_PLUGIN_EXPORT float res_plosive_score(const float *samples,
                                          int32_t sample_count,
                                          int32_t sample_rate,
                                          float prev_low_energy,
                                          float *out_low_energy);

#ifdef __cplusplus
}
#endif

#endif  // RESONANCE_DSP_H
