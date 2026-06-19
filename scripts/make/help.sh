#!/usr/bin/env bash

set -ueo pipefail

usage() { echo "usage: help.sh <makefile>"; }

if (( $# != 1  )); then
  usage
  exit 1
fi

if [[ ! -f "$1" ]]; then
  printf 'error: makefile not found: %s' "$1" >&2
  exit 1
fi

GREEN=$(printf '\033[38;2;11;236;202m')
PURPLE=$(printf '\033[38;2;148;140;243m')
RESET=$(printf '\033[0;39m')

makefile="$1"

printf 'Usage: %s\n' "make ${GREEN}<command>${RESET}"
cat "$makefile" \
  | grep -E -e '^##' -e '(^.+): ##( *)(.+)' \
  | column -t -s: \
  | sed -E "s/^(## *)(.+)/\n\2:\n/" \
  | sed -E "s/(^.+) ## (.+)/  ${PURPLE}\1${RESET}\2/"
