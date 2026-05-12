# shellcheck shell=bash

LIB_VERSION='1.0.0'
LIB_DEPS=()
[[ "${1:-}" = '__IMPORT__' ]] && return 0

TRAP_STORE_EXIT=''
TRAP_STORE_ERR=''

trap::_print_handler() {
  # 設定されているシグナルハンドラを出力(未設定の場合は空)
  # $1: signal
  local signal="$1" trap_str
  trap_str="$(trap -p "$signal")"
  if [[ "$trap_str" =~ trap\ --\ \'(.*)\'\ (SIG)?${signal}$ ]]; then
    printf '%s' "${BASH_REMATCH[1]}"
  fi
}

trap::save_handler() {
  TRAP_STORE_EXIT="$(trap::_print_handler 'EXIT')"
  TRAP_STORE_ERR="$(trap::_print_handler 'ERR')"
}

trap::concat() {
  # 現在のシグナルハンドラの先頭に引数のハンドラを連結する
  # $1: singal, $2: 連結するハンドラ
  local signal="$1" new_handler="${2:?}" current_handler
  current_handler="$(trap::_print_handler "$signal")"
  if [[ -n "$current_handler" ]]; then
    trap -- "${new_handler};${current_handler}" "$signal"
  else
    trap -- "$new_handler" "$signal"
  fi
}

trap::restore_handler() {
  [[ -n "$TRAP_STORE_EXIT" ]] && trap -- "$TRAP_STORE_EXIT" 'EXIT'
  [[ -n "$TRAP_STORE_ERR" ]]  && trap -- "$TRAP_STORE_ERR"  'ERR'
  return 0
}
