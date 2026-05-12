#!/usr/bin/env bash

set -ueo pipefail

DOTFILES_PATH=~/.dotfiles
source "${DOTFILES_PATH}/lib/bash/import.sh"

print_header() {
  local width="$1"
  shift

  for v in "$@"; do
    printf '%-*s ' "$width" "$v"
  done
  printf '\n'
}

print_header_rule() {
  local width line
  for width in "$@"; do
    printf -v line '%*s' "$width" ''
    printf '%s ' "${line// /-}"
  done
  printf '\n'
}

list_imported_libs() {
  local width=24 key
  print_header "$width" 'Library' 'Version'
  print_header_rule 24 24
  for key in "${!IMPORT_IMPORTED_LIBS[@]}"; do
    printf '%-24s %s\n' "$key" "${IMPORT_IMPORTED_LIBS[${key}]}"
  done
}

IMPORT_DEBUG=true

import core esc util log theme escseq msg dotfiles trap termcap

echo

list_imported_libs

echo
echo EOS
