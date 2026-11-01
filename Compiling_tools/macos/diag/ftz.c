// Diagnostic only: load with DYLD_INSERT_LIBRARIES to run a program with
// flush-to-zero and denormals-are-zero on, in the main thread and every thread
// it starts, without recompiling it.
#include <pthread.h>
#include <stdio.h>
#include <stdlib.h>
#include <xmmintrin.h>

static void ftz(void) { _mm_setcsr(_mm_getcsr() | 0x8040); }

__attribute__((constructor)) static void on_load(void) {
  ftz();
  fprintf(stderr, "[ftz] loaded, MXCSR %#x\n", _mm_getcsr());
}
__attribute__((destructor)) static void on_exit_(void) {
  fprintf(stderr, "[ftz] at exit, MXCSR %#x\n", _mm_getcsr());
}

struct start { void *(*fn)(void *); void *arg; };
static void *tramp(void *p) {
  struct start s = *(struct start *)p;
  free(p);
  ftz();
  return s.fn(s.arg);
}
static int my_create(pthread_t *t, const pthread_attr_t *a, void *(*fn)(void *), void *arg) {
  struct start *s = malloc(sizeof *s);
  s->fn = fn;
  s->arg = arg;
  return pthread_create(t, a, tramp, s);
}
__attribute__((used, section("__DATA,__interpose")))
static struct { const void *mine, *theirs; } interpose = { (const void *)my_create, (const void *)pthread_create };
