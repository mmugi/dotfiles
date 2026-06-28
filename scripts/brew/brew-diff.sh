#!/usr/bin/env bash

set -ueo pipefail

# shellcheck source=/dev/null
source "${DOTFILES_PATH}/lib/bash/import.sh"
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
while IFS='' read -r -d '' file; do
  files+=("$file")
done < <(find "$DOTFILES_BREWFILE_DIR" -type f -print0 | sort -z)

msg 'searching for brewfiles...'
if (( ${#files[@]} == 0 )); then
  msg::warning "no files found in ${DOTFILES_BREWFILE_DIR}"
  exit 1
fi

if ! brewfile="$(
  msg::select \
    --ps='choose the brewfile you want to compare: ' \
    "${files[@]}"
)"; then
  msg::failed 'aborted.'
  exit 1
fi

msg 'dumping all packages...'

dump="$(
  HOMEBREW_NO_AUTO_UPDATE=1 HOMEBREW_NO_ENV_HINTS=1 \
    brew bundle dump --file=- --no-describe
)"

if util::chk -cq 'git'; then
  git diff "$brewfile" <(echo "$dump") && msg::ok 'no differences.'
else
  diff -u "$brewfile" <(echo "$dump") && msg::ok 'no differences.'
fi || true
