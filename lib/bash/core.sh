# shellcheck shell=bash

core::_log_header() {
  local line subroutine file type
  type="${1:?}"
  read -r line subroutine file < <(caller 1)
  printf '[CORE: %5s] [%s:%s] [%s]' "$type" "$file" "$line" "$subroutine" >&2
}

core::_log_body() {
  printf ' %s' "$@" >&2
  printf '\n' >&2
}

core::error() { core::_log_header 'ERROR'; core::_log_body "$@"; }
core::warn()  { core::_log_header 'WARN'; core::_log_body "$@"; }
