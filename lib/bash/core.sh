# shellcheck shell=bash

# import.sh がsource時に読み取る変数
# shellcheck disable=SC2034
{
  LIB_VERSION='1.0.0'
  LIB_DEPS=()
}
[[ "${1:-}" = '__IMPORT__' ]] && return 0

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
