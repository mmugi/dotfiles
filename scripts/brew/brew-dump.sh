#!/usr/bin/env bash

set -ueo pipefail

# shellcheck source=/dev/null
source "${DOTFILES_PATH:?}/lib/bash/import.sh"
import msg theme util log dotfiles

msg::init
theme::load

util::chk -c brew

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
    msg::error 'aborted.'
    exit 1
  fi
fi

if [[ "$brewfile" == 'newfile' ]]; then
  filename="$(
    msg::read -e \
      -i "${DOTFILES_BREWFILE_DIR}/" \
      -- 'enter the file name of the new brewfile:'
  )"
  brewfile="${DOTFILES_BREWFILE_DIR}/${filename}"

  if [[ -f "$brewfile" ]]; then
    logger --fatal "file already exists: ${brewfile}"
  fi
fi

msg "dumping all installed packages into <hl>${brewfile}</hl>..."
HOMEBREW_NO_AUTO_UPDATE=1 HOMEBREW_NO_ENV_HINTS=1 \
  brew bundle dump --file "$brewfile" --no-describe --force
msg::ok 'successfully dumped all packages:)'
