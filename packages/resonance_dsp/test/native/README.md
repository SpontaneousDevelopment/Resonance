# Native DSP harness

Two standalone C programs that exercise `src/resonance_dsp.c` directly, with no
Dart involved.

They exist because the Dart tests verify the *binding* — struct layout, buffer
marshalling, lifetime — while these verify the *algorithms*. Pitch accuracy
against synthesised tones, octave and subharmonic rejection, and the frame
budget are all properties of the C, and testing them here keeps the failure
message pointed at the right layer.

```sh
# Correctness — 27 checks. Run by CI.
cc -O2 -I../../src ../../src/resonance_dsp.c dsp_test.c -o /tmp/dsp_test -lm
/tmp/dsp_test

# Performance against the 60 fps budget. Not run by CI: runner timings are too
# noisy to assert on. Run it locally after touching the pitch path.
cc -O2 -I../../src ../../src/resonance_dsp.c bench.c -o /tmp/bench -lm
/tmp/bench
```

`dsp_test.c` covers, among others:

- RMS and dBFS against known values, including the −100 floor for silence.
- Pitch across the vocal range on pure tones, to within 1%.
- Pitch on **sawtooths**, which are harmonic-rich and are what trip naive
  trackers into reporting the octave above.
- Rejection above and below the vocal range. The subharmonic case is the
  interesting one: a 1200 Hz tone is genuinely periodic at 400 Hz, so a search
  restricted to the vocal range would report 400 Hz with full confidence. The
  search runs to 2 kHz and range-checks afterwards, which is why this passes.
- Confidence falling as a tone is buried in noise.
- Voicing gated on the measured room floor rather than an absolute level.
- Plosive detection distinguishing a sudden low burst from a sustained low note.
- Null and zero-length inputs on every entry point.
