#!/usr/bin/env bash

# dotfiles bootstrapper
# dotfilesをダウンロードして、installスクリプトを実行します。

set -ueo pipefail

if [ -z "${BASH_VERSION:-}" ]; then
  printf "\033[1;31m%s\033[0m\n" 'please run this script with bash;('
  exit 1
fi

exec_user=$(whoami)
if [[ "$exec_user" == 'root' ]]; then
  printf "\033[1;31m%s\033[0m\n" "don't run this script as root:<"
  exit 1
fi

: "${DOTFILES_BRANCH:=trunk}"

declare -r DOTFILES_URL='git@github.com:mmugi/dotfiles.git'
declare -r DOTFILES_TARBALL_URL="https://github.com/mmugi/dotfiles/archive/${DOTFILES_BRANCH}.tar.gz"

if [[ -z "${DOTFILES_PATH:-}" ]]; then
  export DOTFILES_PATH="${HOME}/.dotfiles"
  export DOTFILES_PATH_UNDEFINED=1
else
  export DOTFILES_PATH_UNDEFINED=0
fi

declare -r DOTFILES_INSTALL_SCRIPT="${DOTFILES_PATH}/scripts/install.sh"

WHITE=$(printf '\033[38;2;239;247;254m')
RED=$(printf '\033[38;2;234;89;80m')
BLUE_PURPLE=$(printf '\033[38;2;95;95;255m')
PURPLE=$(printf '\033[38;2;148;140;243m')
RESET=$(printf '\033[0;39m')

msg() { printf '%s%s\n' "${BLUE_PURPLE}[>] ${RESET}" "${WHITE}$*${RESET}"; }
msg_proc() { printf '%s%s\n' "${PURPLE}[<] ${RESET}" "${WHITE}$*${RESET}"; }
abort () { printf '%s%s\n' "${RED}[;] " "$*${RESET}"; exit 1; }
newline() { printf '\n'; }

msg 'bootstraping...'

if [[ ! -e "$DOTFILES_PATH" ]]; then
  if [[ -z "${DOTFILES_DOWNLOADER:-}" ]]; then
    if type 'git' >/dev/null 2>&1; then
      downloader='git'
    elif type 'curl' >/dev/null 2>&1; then
      downloader='curl'
    elif type 'wget' >/dev/null 2>&1; then
      downloader='wget'
    else
      abort 'downloader not found'
    fi
  else
    if [[ ! "$DOTFILES_DOWNLOADER" =~ ^(git|curl|wget)$ ]]; then
      abort "invalid downloader: ${DOTFILES_DOWNLOADER}"
    elif type "$DOTFILES_DOWNLOADER" >/dev/null 2>&1; then
      downloader="$DOTFILES_DOWNLOADER"
    else
      abort 'downloader not found'
    fi
  fi

  msg_proc 'downloading dotfiles...'

  if [[ "$downloader" == 'git' ]]; then
    git clone --recursive -b "$DOTFILES_BRANCH" "$DOTFILES_URL" "$DOTFILES_PATH"
  elif [[ "$downloader" =~ ^(curl|wget)$ ]]; then
    type 'tar' >/dev/null 2>&1 || abort 'command not found: tar'
    mkdir "$DOTFILES_PATH"
    case "$downloader" in
      curl) curl -fsSL "$DOTFILES_TARBALL_URL" ;;
      wget) wget -qO - "$DOTFILES_TARBALL_URL" ;;
    esac | tar xvz -C "$DOTFILES_PATH" --strip-components=1
  else
    abort "invalid downloader: ${downloader}"
  fi
fi

newline
exec "$DOTFILES_INSTALL_SCRIPT"
