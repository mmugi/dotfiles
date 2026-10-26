#!/usr/bin/env bash
#
# Adds an include.path entry to the global git config that loads the git
# config deployed by the dotfiles. Does nothing if the entry is already there.

set -ueo pipefail

# shellcheck source=/dev/null
source "${DOTFILES_PATH:?}/lib/bash/import.sh"
import msg theme

theme::load

hl="${STYLE[msg_highlight]}"
base="${STYLE[normal]}"

# git が ~ を展開するので、ホームの場所に依存しない形で書く
# shellcheck disable=SC2088
include_path='~/.config/git/config.dotfiles'

# include.path は ~ でも絶対パスでも書けるので、--type=path で ~ を展開してから比べる
if git config --global --type=path --get-all include.path 2>/dev/null \
  | grep -qxF "${HOME}/.config/git/config.dotfiles"; then
  msg::skipped "include.path already exists in the global git config."
  exit 0
fi

git config --global --add include.path "$include_path"
msg::changed "added include.path to the global git config: ${hl}${include_path}${base}"
