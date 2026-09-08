# shellcheck shell=bash

# import.sh がsource時に読み取る変数
# shellcheck disable=SC2034
{
  LIB_DEPS=()
}
[[ "${1:-}" = '__IMPORT__' ]] && return 0

: "${TERMCAP_COLOR_MODE:=auto}"

termcap::is_tty() {
  local fd="${1:-1}"
  [[ -t "$fd" ]]
}

termcap::is_color_supported() {
  local fd="${1:-1}"
  [[ -n "${NO_COLOR:-}" ]] && return 1
  case "$TERMCAP_COLOR_MODE" in
    always) return 0 ;;
    never) return 1 ;;
    auto) termcap::is_tty "$fd" ;;
    *) return 1 ;;
  esac
}
