import 'dart:typed_data';

/// Re-chunks a stream of arbitrarily-sized PCM byte buffers into fixed-length
/// float frames.
///
/// The recorder hands back whatever the platform's audio callback happened to
/// deliver — often 1024 bytes, sometimes 4096, occasionally a ragged tail. The
/// analyser needs exactly [frameSize] samples every time. This sits between
/// them and holds the remainder across callbacks.
///
/// Getting this wrong is subtle and nasty: dropping the remainder loses a few
/// milliseconds per callback, which over a 90-second take accumulates into a
/// pitch contour that drifts out of sync with the audio it describes.
class FrameBuffer {
  FrameBuffer({required this.frameSize})
    : assert(frameSize > 0),
      _pending = Float32List(frameSize);

  final int frameSize;

  /// Partially-filled frame carried between callbacks.
  final Float32List _pending;
  int _pendingCount = 0;

  /// Total samples ever accepted. Drives the elapsed-time readout, which must
  /// come from the audio clock rather than a wall clock — they diverge, and
  /// the audio clock is the one the waveform is drawn against.
  int get samplesConsumed => _samplesConsumed;
  int _samplesConsumed = 0;

  /// Feeds signed 16-bit little-endian PCM, the format the recorder streams.
  ///
  /// Returns however many complete frames that produced — usually zero or one,
  /// occasionally more after a large callback.
  List<Float32List> addPcm16(Uint8List bytes) {
    final sampleCount = bytes.lengthInBytes ~/ 2;
    if (sampleCount == 0) return const [];

    final view = ByteData.sublistView(bytes);
    final samples = Float32List(sampleCount);
    for (var i = 0; i < sampleCount; i++) {
      // 32768 rather than 32767: the negative range is one larger, and dividing
      // by 32767 lets a full-scale negative sample exceed -1.0, which then
      // reads as clipping on audio that never clipped.
      samples[i] = view.getInt16(i * 2, Endian.little) / 32768.0;
    }
    return addSamples(samples);
  }

  /// Feeds float samples directly.
  List<Float32List> addSamples(Float32List samples) {
    _samplesConsumed += samples.length;

    final frames = <Float32List>[];
    var offset = 0;

    while (offset < samples.length) {
      final room = frameSize - _pendingCount;
      final take = (samples.length - offset) < room
          ? (samples.length - offset)
          : room;

      _pending.setRange(_pendingCount, _pendingCount + take, samples, offset);
      _pendingCount += take;
      offset += take;

      if (_pendingCount == frameSize) {
        // Copy: the caller may hold on to a frame, and _pending is about to be
        // overwritten by the next callback.
        frames.add(Float32List.fromList(_pending));
        _pendingCount = 0;
      }
    }

    return frames;
  }

  /// The incomplete tail, zero-padded to a full frame, or null if empty.
  ///
  /// Called once when a recording stops so the last fraction of a second is
  /// analysed rather than silently discarded.
  Float32List? flush() {
    if (_pendingCount == 0) return null;
    final frame = Float32List(frameSize);
    frame.setRange(0, _pendingCount, _pending);
    _pendingCount = 0;
    return frame;
  }

  void reset() {
    _pendingCount = 0;
    _samplesConsumed = 0;
  }
}
