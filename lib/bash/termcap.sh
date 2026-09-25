# shellcheck shell=bash

: "${TERMCAP_COLOR_MODE:=auto}"

termcap::is_color_supported() {
  local fd="${1:-1}"
  [[ -n "${NO_COLOR:-}" ]] && return 1
  case "$TERMCAP_COLOR_MODE" in
    always) return 0 ;;
    never) return 1 ;;
    auto) [[ -t "$fd" ]] ;;
    *) return 1 ;;
  esac
}
