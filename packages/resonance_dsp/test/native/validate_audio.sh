#!/usr/bin/env bash
# Validates the plosive detector against real speech, with pops at known times.
#
# This exists because the detector shipped reporting 284 pops a minute on real
# recordings while passing every synthetic test. Sine tones cannot tell you
# whether a detector fires on ordinary speech; only speech can.
#
# `say` gives real formants, real coarticulation and natural loudness variation.
# It has no microphone capsule, so it contains no pops at all — which makes the
# clean files a true-negative set with known ground truth. Pops are then
# injected at known times to make a true-positive set.
#
# Run from the repo root: ./packages/resonance_dsp/test/native/validate_audio.sh

set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="$HERE/../../src"
WORK="${TMPDIR:-/tmp}/resonance_plosive_validation"
mkdir -p "$WORK"

echo "Generating speech…"
say -o "$WORK/plosive_rich.wav" --data-format=LEF32@48000 \
  "Peter picked a bitter batch of pickled peppers, packed them tight, and put the barrel back beside the broken gate."
say -o "$WORK/no_plosive.wav" --data-format=LEF32@48000 \
  "She sells sea shells and the shells she sells are surely seaside shells."
say -o "$WORK/low_voice.wav" -v Daniel --data-format=LEF32@48000 \
  "The rolling swell of the ocean rose and fell below the old harbour wall."

echo "Building…"
cc -O2 -I"$SRC" "$SRC/resonance_dsp.c" "$HERE/audio_probe.c" "$HERE/wav_reader.c" -o "$WORK/probe" -lm
cc -O2 "$HERE/inject_pops.c" "$HERE/wav_reader.c" -o "$WORK/inject" -lm

"$WORK/inject" "$WORK/plosive_rich.wav" "$WORK/popped.wav"

echo
echo "TRUE NEGATIVES — synthesised speech has no capsule, so ground truth is 0 pops:"
for f in plosive_rich no_plosive low_voice; do "$WORK/probe" "$WORK/$f.wav"; echo; done

echo "TRUE POSITIVES — same speech with 5 pops injected at known times:"
"$WORK/probe" "$WORK/popped.wav" --frames
