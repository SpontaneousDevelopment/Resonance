#include "resonance_dsp.h"
#include <math.h>
#include <stdio.h>
#include <time.h>

#define SR 48000

static void fill_saw(float *b, int n, float hz) {
  const float period = (float)SR / hz;
  for (int i = 0; i < n; i++) b[i] = 0.6f * (2.0f * fmodf((float)i, period) / period - 1.0f);
}

int main(void) {
  const int windows[] = {1024, 2048, 4096};
  printf("%-8s %-12s %-14s %-14s %s\n", "window", "ms/frame", "frames/sec", "budget @60fps", "verdict");
  for (int w = 0; w < 3; w++) {
    const int n = windows[w];
    static float buf[4096];
    static float scratch[2048];
    fill_saw(buf, n, 147.0f);

    const int iters = 2000;
    ResFrameAnalysis fa;
    struct timespec t0, t1;
    clock_gettime(CLOCK_MONOTONIC, &t0);
    for (int i = 0; i < iters; i++) {
      res_analyse_frame(buf, n, SR, -60.0f, scratch, &fa);
    }
    clock_gettime(CLOCK_MONOTONIC, &t1);

    const double sec = (t1.tv_sec - t0.tv_sec) + (t1.tv_nsec - t0.tv_nsec) / 1e9;
    const double ms = sec * 1000.0 / iters;
    const double pct = ms / 16.67 * 100.0;
    printf("%-8d %-12.4f %-14.0f %-13.1f%% %s\n", n, ms, 1.0 / (sec / iters), pct,
           pct < 10 ? "comfortable" : pct < 30 ? "fine" : pct < 70 ? "tight" : "TOO SLOW");
  }
  return 0;
}
