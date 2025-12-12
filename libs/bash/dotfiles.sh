#!/usr/bin/env bash

: LIBRARY METADATA
# shellcheck disable=SC2034
{
  LIB_VERSION='1.0.0'
  LIB_DEPS=()
  [[ ${1:-} = __META_PROBE__ ]] && return 0
}

# shellcheck disable=SC2034
dotfiles::env() {
  readonly DOTFILES_LOGO_WIDTH=67
  readonly DOTFILES_LOGO='
    _____  _______ _______ _______ _______ _____   _______ _______
   |     \|       |_     _|    ___|_     _|     |_|    ___|     __|
 __|  --  |   -   | |   | |    ___|_|   |_|       |    ___|__     |
|__|_____/|_______| |___| |___|   |_______|_______|_______|_______|'
}
