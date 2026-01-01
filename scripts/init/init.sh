#!/usr/bin/env bash

set -ueo pipefail

# shellcheck source=/dev/null
source "${DOTFILES_PATH}/libs/bash/import.sh"
import msg util log

[[ "${DOTFILES_INIT:-}" != 'true' ]] && abort 'DOTFILES_INIT is not true'

cd "$DOTFILES_PATH"

msg 'checking requirements.'
util::sysinfo --os
util::chk -c make
make init-os
