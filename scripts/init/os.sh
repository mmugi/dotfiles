#!/usr/bin/env bash

set -ueo pipefail

# shellcheck source=/dev/null
source "${DOTFILES_PATH}/lib/bash/import.sh"
import util msg log

_start() {
  if msg::confirm -y "proceed with the initial <b><hl>${DOTFILES_SYS_OS}</hl></b> setup?"; then
    msg "starting initializing for ${DOTFILES_SYS_OS}."
  else
    msg::marker --terminate 'aborting initial os setup;('
    exit 1
  fi
}

_end() {
  msg::marker --complete "initial ${DOTFILES_SYS_OS} setup completed:)"
}

init_macos() {
  _start

  msg -p 'installing command line tools for xcode'
  if gcc --version >/dev/null 2>&1; then
    msg --highlight=complete 'command line tools are already installed!'
  else
    xcode-select --install
  fi

  ### rosettaインストールの自動化が必要になった場合に使用予定
  #util::sysinfo --arch
  #case "$DOTFILES_SYS_ARCH" in
  #  arm64) apple_silicon=true ;;
  #  *)
  #    newline
  #    abort "unsupported architecture: ${DOTFILES_SYS_ARCH}"
  #    ;;
  #esac

  #if [[ "$apple_silicon" == 'true' ]]; then
  #  : rosetta installation
  #fi

  _end
}

# --- main ---

util::sysinfo --os

if [[ "$DOTFILES_SYS_OS" == 'macos' ]]; then
  init_macos
else
  abort "unsupported platform: $DOTFILES_SYS_OS"
fi
