#!/usr/bin/env bash

set -ueo pipefail

# shellcheck source=/dev/null
source "${DOTFILES_PATH:?}/lib/bash/import.sh"
import msg theme util log dotfiles

msg::init
theme::load

if ! util::chk -c brew; then
  logger --fatal 'command not found: brew'
fi

if [[ ! -d "$DOTFILES_BREWFILE_DIR" ]]; then
  logger --fatal "directory not found: ${DOTFILES_BREWFILE_DIR}"
fi

# 通常ファイルのみを収集
msg 'searching for brewfiles...'
while IFS='' read -r -d '' file; do
  files+=("$file")
done < <(find "$DOTFILES_BREWFILE_DIR" -type f -print0 | sort -z)

if (( ${#files[@]} == 0 )); then
  msg::notice "no files found in ${DOTFILES_BREWFILE_DIR}"
  brewfile=newfile
else
  if ! brewfile="$(
    msg::select \
      --ps='select a brewfile to dump: ' \
      newfile "${files[@]}"
  )"; then
    msg::failed 'aborted.'
    exit 1
  fi
fi

if [[ "$brewfile" == 'newfile' ]]; then
  filename="$(msg::read 'enter the file name of the new brewfile: ')"
  brewfile="${DOTFILES_BREWFILE_DIR}/${filename}"

  if [[ -f "$brewfile" ]]; then
    logger --fatal "file already exists: ${brewfile}"
  fi
fi

msg::proc "dumping all installed packages into <hl>${brewfile}</hl>..."
brew bundle dump --file "$brewfile" --no-describe --force
msg::ok 'successfully dumped all packages:)'
