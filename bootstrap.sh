#!/usr/bin/env bash

# dotfiles bootstrapper
# dotfilesをダウンロードして、installスクリプトを実行します。

set -Eueo pipefail

if [ -z "${BASH_VERSION:-}" ]; then
  printf "\033[1;31m%s\033[0m\n" 'please run this script with bash;('
  exit 1
fi

RED=$(printf '\033[38;5;166m')
CYAN=$(printf '\033[38;5;195m')
PURPLE=$(printf '\033[38;5;105m')
BOLD=$(printf '\033[1m')
RESET=$(printf '\033[0;39m')

: "${DOTFILES_BRANCH:=trunk}"

if [[ -z "${DOTFILES_PATH:-}" ]]; then
  DOTFILES_PATH="${HOME}/.dotfiles"
  DOTFILES_PATH_UNDEFINED=true
else
  DOTFILES_PATH_UNDEFINED=false
fi
export DOTFILES_PATH
export DOTFILES_PATH_UNDEFINED

readonly DOTFILES_URL='git@github.com:mmugi/dotfiles.git'
readonly DOTFILES_TARBALL_URL="https://github.com/mmugi/dotfiles/archive/${DOTFILES_BRANCH}.tar.gz"

msg() {
  printf '%s%s\n' "${BOLD}${PURPLE}> ${RESET}" "${CYAN}$*${RESET}"
  sleep 0.2
}

abort() {
  printf '%s: %s: line %s: %s: %s\n' \
    "${BOLD}${RED}ERROR${RESET}" \
    "${BASH_SOURCE[0]##*/}" \
    "${BASH_LINENO[0]}" \
    "${FUNCNAME[1]:-main}" \
    "$*" >&2
  exit 1
}

exec_user=$(whoami)
[[ "$exec_user" == 'root' ]] && abort "don't run this script as root"

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

  msg 'downloading dotfiles...'

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

exec "${DOTFILES_PATH}/scripts/install.sh"
