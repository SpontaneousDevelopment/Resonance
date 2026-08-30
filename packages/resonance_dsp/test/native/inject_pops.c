// Builds a validation file: real speech with synthetic microphone pops injected
// at known times, so detection can be measured against ground truth.
//
// A mic pop is an aerodynamic artefact — a burst of breath hitting the capsule.
// It is a fast-attack, low-frequency transient (~60-120 Hz) decaying over
// 60-150 ms. TTS audio has no capsule and therefore no pops, which is why the
// clean speech files score zero and why they alone cannot validate a detector.
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#define SR 48000
float *read_wav(const char *path, long *count);

int main(int argc, char **argv) {
  long n; float *a = read_wav(argv[1], &n);
  // Inject at these seconds.
  const double when[] = {1.0, 2.5, 4.0, 5.5, 7.0};
  const int count = (int)(sizeof when / sizeof when[0]);

  for (int p = 0; p < count; p++) {
    long start = (long)(when[p] * SR);
    if (start + SR / 4 >= n) continue;
    const double hz = 70.0 + p * 12.0;         // pops vary in pitch
    const double amp = 0.55;                    // loud but not clipping
    const double decay = 0.085;                 // ~85 ms
    for (long i = 0; i < SR / 4; i++) {
      double t = (double)i / SR;
      double env = exp(-t / decay);
      a[start + i] += (float)(amp * env * sin(2.0 * M_PI * hz * t));
      if (a[start + i] > 1.0f) a[start + i] = 1.0f;
      if (a[start + i] < -1.0f) a[start + i] = -1.0f;
    }
  }

  // Write a minimal float32 WAV.
  FILE *f = fopen(argv[2], "wb");
  unsigned int datasize = (unsigned)(n * 4), riff = 36 + datasize, rate = SR,
               byterate = SR * 4;
  unsigned short one = 1, three = 3, chans = 1, block = 4, bits = 32;
  unsigned int sixteen = 16;
  fwrite("RIFF", 1, 4, f); fwrite(&riff, 4, 1, f); fwrite("WAVE", 1, 4, f);
  fwrite("fmt ", 1, 4, f); fwrite(&sixteen, 4, 1, f);
  fwrite(&three, 2, 1, f); fwrite(&chans, 2, 1, f);
  fwrite(&rate, 4, 1, f); fwrite(&byterate, 4, 1, f);
  fwrite(&block, 2, 1, f); fwrite(&bits, 2, 1, f);
  fwrite("data", 1, 4, f); fwrite(&datasize, 4, 1, f);
  fwrite(a, 4, n, f);
  fclose(f);
  (void)one;
  printf("wrote %s with %d pops at:", argv[2], count);
  for (int p = 0; p < count; p++) printf(" %.1fs", when[p]);
  printf("\n");
  return 0;
}
