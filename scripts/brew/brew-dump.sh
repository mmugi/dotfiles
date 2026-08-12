#!/usr/bin/env bash

set -ueo pipefail

# shellcheck source=/dev/null
source "${DOTFILES_PATH:?}/lib/bash/import.sh"
import msg theme util log dotfiles

theme::load
msg::init

util::chk -c brew

if [[ ! -d "$DOTFILES_BREWFILE_DIR" ]]; then
  logger --fatal "directory not found: ${DOTFILES_BREWFILE_DIR}"
fi

# 通常ファイルのみを収集
# 1件も無い場合に ${#files[@]} が set -u で落ちないよう、先に宣言する
declare -a files=()

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
  # -i でディレクトリを初期値として入れているため、入力結果はフルパスで返る。
  # ここで DOTFILES_BREWFILE_DIR を再度前置すると二重になる。
  if ! brewfile="$(
    msg::read -e \
      -i "${DOTFILES_BREWFILE_DIR}/" \
      -- 'enter the path of the new brewfile: '
  )"; then
    msg::error 'aborted.'
    exit 1
  fi

  if [[ -z "$brewfile" || "$brewfile" == */ ]]; then
    logger --fatal 'file name is not specified'
  fi

  if [[ -e "$brewfile" ]]; then
    logger --fatal "file already exists: ${brewfile}"
  fi

  # 初期値を消して別のディレクトリを打った場合に備える
  brewfile_dir="$(dirname -- "$brewfile")"
  if [[ ! -d "$brewfile_dir" ]]; then
    logger --fatal "directory not found: ${brewfile_dir}"
  fi
fi

msg "dumping all installed packages into <hl>${brewfile}</hl>..."
HOMEBREW_NO_AUTO_UPDATE=1 HOMEBREW_NO_ENV_HINTS=1 \
  brew bundle dump --file "$brewfile" --no-describe --force
msg::ok 'successfully dumped all packages:)'
