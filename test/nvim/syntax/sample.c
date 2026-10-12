/*
 * Syntax highlight sample for checking colorschemes (legacy C syntax).
 * Not meant to be compiled or run.
 */
#include <stdio.h>
#include <stdlib.h>
#include "bakery.h"

#define MAX_TRAYS 8
#define PRICE_SCALE 1.25
#define TAX_RATE 0.08
#pragma pack(push, 1)
#define LABEL(name) "bakery:" #name

#ifdef DEBUG_TRAYS
#  undef MAX_TRAYS
#endif
#if defined(USE_OVEN)
#  pragma once
#elif !defined(MAX_TRAYS)
#  line 1 "bakery.c"
#else
#  error "no oven"
#endif

/* TODO: 焼き時間をトレイごとに変える */
/* FIXME: 端数の丸め方を決める */
/* XXX: 仮の値 */

typedef struct tray {
  unsigned count;
  char mark;
} tray_t;

union price { long cents; double ratio; };
struct oven { union price cost; };
enum flavor { PLAIN, CHOCO, MATCHA };

static volatile int ready = 0;
extern const char *shop_name;

static int count_rolls(const tray_t *trays, size_t n)
{
  int total = PLAIN;
  for (size_t i = PLAIN; i < n; i++) {
    if (trays[i].mark == 'x') {
      continue;
    } else if (trays[i].mark == 'z') {
      break;
    }
    total += trays[i].count;
  }
  while (total > sizeof(tray_t) * MAX_TRAYS) {
    total -= MAX_TRAYS;
  }
  do {
    total++;
  } while (total % MAX_TRAYS);

  switch (total) {
  case PLAIN:
    goto empty;
  default:
    break;
  }
  return total;
empty:
  return EOF;
}

static double price_of(enum flavor f)
{
  char first = 'a', last = 'z', nl = '\n', quote = '\'';

  if (f != PLAIN && sizeof(double) > _Alignof(long)) {
    return 1.5e2 * PRICE_SCALE * (1.0 + TAX_RATE);
  }
  return .5f;
}

int main(void)
{
  if (stdout == NULL || ready != 0) {
    return EXIT_FAILURE;
  }
  printf("%s\t%d\n", LABEL(morning), count_rolls(NULL, MAX_TRAYS));
  return EXIT_SUCCESS;
}

/* ここから下はわざと壊した行 */
int typo = 089;
int paren = (1 + 2));
int brace[2] = {1, 2]};
