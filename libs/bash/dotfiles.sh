#!/usr/bin/env bash

set -Eueo pipefail

LIB_VERSION='1.0.0'
LIB_DEPS='esc msg'
[[ ${1:-} = __META_PROBE__ ]] && return 0

: "${DOTFILES_MSG_DELAY:=0.2}"
: "${DOTFILES_C_LINE:=$ESC_TAG_MAIN}"
: "${DOTFILES_C_LOGO:=$ESC_TAG_BASE}"

dotfiles.line() {
  local -r length=67
  local -r symbol='.'
  local line
  for i in $(seq "$length"); do
    line=$(printf "${symbol}%.0s" $(seq 1 "$i"))
    printf "\r%s" "${DOTFILES_C_LINE}${line}${ESC_RESET}"
    sleep 0.002
  done
  echo
}

dotfiles.logo() {
  local -r logo='
    _____  _______ _______ _______ _______ _____   _______ _______
   |     \|       |_     _|    ___|_     _|     |_|    ___|     __|
 __|  --  |   -   | |   | |    ___|_|   |_|       |    ___|__     |
|__|_____/|_______| |___| |___|   |_______|_______|_______|_______|'
  printf "%s\n\n" "${ESC_ATTR_BOLD}${DOTFILES_C_LOGO}${logo}${ESC_RESET}"
  sleep "$MSG_DELAY"
}
