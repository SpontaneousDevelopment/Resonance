#include <stdio.h>
#include <stdlib.h>
#include <string.h>
float *read_wav(const char *path, long *count) {
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
