#!/usr/bin/env bash

set -u

# shellcheck source=/dev/null
source "${DOTFILES_PATH}/lib/bash/import.sh"
import msg util log

[[ "${DOTFILES_INIT:-}" != 'true' ]] && abort 'DOTFILES_INIT is not true'

cd "$DOTFILES_PATH" || exit

msg 'checking requirements.'
util::sysinfo --os
util::chk -c make
make init-os
make init-git-sign
