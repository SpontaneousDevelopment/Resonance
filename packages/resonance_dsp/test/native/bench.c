// Frame-budget check for the DSP core.
//
// This used to print a table and a verdict word, and exit 0 whatever it
// measured — a number nobody could regress against, which is the shape of
// check this project has been bitten by repeatedly. It now asserts an absolute
// budget for the window production actually uses and fails the build when that
// budget is exceeded.
#include "resonance_dsp.h"
#include <math.h>
#include <stdio.h>
#include <time.h>

#define SR 48000

// The window the app runs at. The others are measured for context only —
// changing this constant means changing what the app does, not what is tested.
#define PRODUCTION_WINDOW 2048

// Ceiling for one frame of analysis, in milliseconds.
//
// A 60 fps frame is 16.67 ms and the measured cost is ~1.14 ms, so this is
// roughly 3.5x headroom. Deliberately not set just above the measurement: the
// point is to catch an algorithmic regression, not to fail on a loaded CI
// runner. Anything approaching 4 ms means a quarter of the frame is going to
// pitch detection, which is where the FFI split stops paying for itself.
#define BUDGET_MS 4.0

static void fill_saw(float *b, int n, float hz) {
  const float period = (float)SR / hz;
  for (int i = 0; i < n; i++) b[i] = 0.6f * (2.0f * fmodf((float)i, period) / period - 1.0f);
}

static double measure(int n) {
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
  return sec * 1000.0 / iters;
}

int main(void) {
  const int windows[] = {1024, 2048, 4096};
  double production_ms = -1.0;

  printf("%-8s %-12s %-14s %s\n", "window", "ms/frame", "frames/sec", "budget @60fps");
  for (int w = 0; w < 3; w++) {
    const int n = windows[w];
    const double ms = measure(n);
    if (n == PRODUCTION_WINDOW) production_ms = ms;
    printf("%-8d %-12.4f %-14.0f %.1f%%\n", n, ms, 1000.0 / ms, ms / 16.67 * 100.0);
  }

  if (production_ms < 0.0) {
    printf("\nFAIL  the production window (%d) was never measured\n", PRODUCTION_WINDOW);
    return 1;
  }

  if (production_ms > BUDGET_MS) {
    printf("\nFAIL  %d-sample analysis took %.4f ms, over the %.1f ms budget\n",
           PRODUCTION_WINDOW, production_ms, BUDGET_MS);
    printf("      That is %.1f%% of a 60 fps frame, spent before anything is drawn.\n",
           production_ms / 16.67 * 100.0);
    return 1;
  }

  printf("\nok    %d-sample analysis: %.4f ms, under the %.1f ms budget\n",
         PRODUCTION_WINDOW, production_ms, BUDGET_MS);
  return 0;
}
