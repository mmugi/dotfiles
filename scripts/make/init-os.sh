#!/usr/bin/env bash

set -ueo pipefail

source "${DOTFILES_PATH}/libs/bash/import.sh"
import util msg log

init_macos() {
  msg 'starting initializing for macos.'

  msg -p 'installing command line tools for xcode'
  if gcc --version >/dev/null 2>&1; then
    msg -R 'command line tools are already installed!'
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

  msg::marker --complete 'macos initialized:)'
}

# --- main ---

util::sysinfo --os
if msg::confirm -y 'proceed with the initial <b><hl>macos</hl></b> setup?'; then
  case "$DOTFILES_SYS_OS" in
    macos) init_macos ;;
    *) abort "unsupported platform: $DOTFILES_SYS_OS" ;;
  esac
else
  msg::marker --terminate 'aborting initial os setup;('
fi
