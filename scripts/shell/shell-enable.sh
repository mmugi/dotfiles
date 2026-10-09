#!/usr/bin/env bash
#
# Appends a line to ~/.<shell>rc that sources the shell config deployed by
# the dotfiles. Does nothing if the line is already there.

set -ueo pipefail

# shellcheck source=/dev/null
source "${DOTFILES_PATH:?}/lib/bash/import.sh"
import msg theme

theme::load

hl="${STYLE[msg_highlight]}"
base="${STYLE[normal]}"

shell="${1:-}"

case "$shell" in
  bash | zsh) ;;
  '')
    msg::error 'no shell specified (supported: bash zsh)'
    exit 1
    ;;
  *)
    msg::error "unsupported shell: ${shell} (supported: bash zsh)"
    exit 1
    ;;
esac

rc="${HOME}/.${shell}rc"

# shellcheck disable=SC2016
source_line='[ -r "$HOME/.config/'"$shell"'/'"$shell"'rc" ] && . "$HOME/.config/'"$shell"'/'"$shell"'rc"'

if [[ -f "$rc" ]] && grep -qxF "$source_line" "$rc"; then
  msg::skipped "source line already exists in ${hl}${rc}${base}."
  exit 0
fi

printf '\n%s\n' "$source_line" >> "$rc"
msg::changed "added source line to ${hl}${rc}${base}"
