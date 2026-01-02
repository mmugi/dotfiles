#!/usr/bin/env bash

set -ueo pipefail

source "${DOTFILES_PATH}/lib/bash/import.sh"
import msg util log dotfiles

BREWFILE_DUMP='/tmp/brewdump'

select_brewfile() {
  [[ -d "$DOTFILES_BREWFILE_DIR" ]] || abort "directory not found: ${DOTFILES_BREWFILE_DIR}"

  local -a files=()
  local f

  # 通常ファイルのみを収集
  while IFS= read -r -d '' f; do
    files+=("$f")
  done < <(find "$DOTFILES_BREWFILE_DIR" -type f -print0 | sort -z)

  (( "${#files[@]}" )) || abort "no files found in ${DOTFILES_BREWFILE_DIR}"

  PS3='choose the brewfile you want to compare: '
  COLUMNS=1
  select f in "${files[@]}" quit; do
    if [[ -z "$f" ]]; then
      log::error 'invalid selection'
      continue
    fi
    printf '%s' "$f"
    break
  done
}

util::chk -c brew

msg 'comparing the current system with the brewfile.'
brewfile="$(select_brewfile)"
if [[ "$brewfile" == 'quit' ]]; then
  msg::marker --terminate 'quit'
  exit 1
fi

msg -p 'dumping all installed casks/formulae/images/taps into a brewfile'
brew bundle dump --force --file "$BREWFILE_DUMP"
newline

if util::chk -cq 'git'; then
  git diff "$brewfile" "$BREWFILE_DUMP" || true
else
  diff -u "$brewfile" "$BREWFILE_DUMP" || true
fi
