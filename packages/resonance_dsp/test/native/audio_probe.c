// Frame-by-frame diagnostic over real audio. Not shipped — this is the
// measurement that should have existed before the detector was wired up.
#include "resonance_dsp.h"
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define SR 48000
#define FRAME 2048
#define THRESHOLD 0.55f

// Minimal WAV reader for the float32 files `say` produces.
static float *read_wav(const char *path, long *count) {
  FILE *f = fopen(path, "rb");
  if (!f) { perror(path); exit(1); }
  unsigned char hdr[12];
  if (fread(hdr, 1, 12, f) != 12) exit(1);
  if (memcmp(hdr, "RIFF", 4) || memcmp(hdr + 8, "WAVE", 4)) {
    fprintf(stderr, "%s: not a WAVE file\n", path); exit(1);
  }
  int channels = 1, bits = 32;
  float *data = NULL; long n = 0;
  for (;;) {
    unsigned char ch[8];
    if (fread(ch, 1, 8, f) != 8) break;
    unsigned int size = ch[4] | (ch[5] << 8) | (ch[6] << 16) | ((unsigned)ch[7] << 24);
    if (!memcmp(ch, "fmt ", 4)) {
      unsigned char fmt[40];
      unsigned int take = size > sizeof fmt ? sizeof fmt : size;
      if (fread(fmt, 1, take, f) != take) break;
      channels = fmt[2] | (fmt[3] << 8);
      bits = fmt[14] | (fmt[15] << 8);
      if (size > take) fseek(f, size - take, SEEK_CUR);
    } else if (!memcmp(ch, "data", 4)) {
      long samples = size / (bits / 8);
      float *raw = malloc(size);
      if (fread(raw, 1, size, f) != size) { /* short read tolerated */ }
      n = samples / channels;
      data = malloc(n * sizeof(float));
      for (long i = 0; i < n; i++) data[i] = raw[i * channels];  // left channel
      free(raw);
      break;
    } else {
      fseek(f, size + (size & 1), SEEK_CUR);
    }
  }
  fclose(f);
  if (!data) { fprintf(stderr, "%s: no data chunk\n", path); exit(1); }
  *count = n;
  return data;
}

int main(int argc, char **argv) {
  if (argc < 2) { fprintf(stderr, "usage: probe FILE.wav [--frames]\n"); return 1; }
  const int verbose = argc > 2 && !strcmp(argv[2], "--frames");

  long n = 0;
  float *audio = read_wav(argv[1], &n);
  const long frames = n / FRAME;

  ResPlosiveState st;
  res_plosive_init(&st);
  int hits = 0, voiced_frames = 0;
  int clusters = 0, run = 0, longest_run = 0;
  float max_score = 0.0f, sum_score = 0.0f;
  int runs[64] = {0};

  printf("%s — %ld frames (%.1f s)\n", argv[1], frames, (double)n / SR);
  if (verbose) printf("%-8s %-8s %-8s %s\n", "frame", "t(s)", "score", "hit");

  for (long i = 0; i < frames; i++) {
    float *frame = audio + i * FRAME;
    float rms = res_rms(frame, FRAME);
    float score = res_plosive_score(frame, FRAME, SR, &st);

    if (res_to_db(rms) > -45.0f) voiced_frames++;
    sum_score += score;
    if (score > max_score) max_score = score;

    const int hit = score >= THRESHOLD;
    if (hit) {
      hits++;
      run++;
      if (run > longest_run) longest_run = run;
    } else {
      if (run > 0) { clusters++; if (run < 64) runs[run]++; }
      run = 0;
    }
    if (verbose && (hit || score > 0.2f)) {
      printf("%-8ld %-8.2f %-8.3f %s\n", i, (double)i * FRAME / SR, score,
             hit ? "HIT" : "");
    }
  }
  if (run > 0) { clusters++; if (run < 64) runs[run]++; }

  const double seconds = (double)n / SR;
  printf("  frames above threshold : %d / %ld\n", hits, frames);
  printf("  distinct clusters      : %d  (longest run %d frames)\n", clusters, longest_run);
  printf("  run-length histogram   : ");
  for (int r = 1; r < 8; r++) if (runs[r]) printf("%dx%d ", runs[r], r);
  printf("\n");
  printf("  mean score             : %.3f   max %.3f\n", sum_score / frames, max_score);
  printf("  RATE AS COUNTED NOW    : %.0f events/min\n", hits / seconds * 60.0);
  printf("  rate if clustered      : %.0f events/min\n", clusters / seconds * 60.0);
  return 0;
}
