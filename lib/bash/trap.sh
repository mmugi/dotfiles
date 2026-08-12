# shellcheck shell=bash

# import.sh がsource時に読み取る変数
# shellcheck disable=SC2034
{
  LIB_VERSION='1.0.0'
  LIB_DEPS=( core )
}
[[ "${1:-}" = '__IMPORT__' ]] && return 0

# Trap Handler <trap.sh>
#
# * Usage *
#
#   # 現在のハンドラを退避
#   trap::save_handler EXIT INT
#
#   # 既存のハンドラの前に自分のハンドラを連結
#   trap::concat EXIT 'cleanup'
#
#   # 退避したハンドラに戻す(退避時に未設定だったシグナルは解除される)
#   trap::restore_handler
#
# * Description *
#
#   一時的にシグナルハンドラを差し込み、処理後に元の状態へ戻すための
#   ヘルパー。stty で端末状態を変える区間などで利用します。
#
#   退避内容は `_TRAP_STORE` 連想配列にシグナル名をキーとして保持します。
#   `trap::save_handler` を引数なしで呼んだ場合は EXIT と ERR を退避します。

declare -gA _TRAP_STORE=()

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
  # 指定シグナルの現在のハンドラを退避する
  # 引数省略時は EXIT と ERR を対象にする
  local signal
  local -a signals=( "$@" )

  (( $# == 0 )) && signals=( 'EXIT' 'ERR' )

  for signal in "${signals[@]}"; do
    # 未設定のシグナルも「未設定だった」ことを記録する必要があるため、
    # 値が空でもキーは作る。
    _TRAP_STORE["$signal"]="$(trap::_print_handler "$signal")"
  done
}

trap::concat() {
  # 現在のシグナルハンドラの先頭に引数のハンドラを連結する
  # $1: signal / $2: 連結するハンドラ
  local signal="${1:?}" new_handler="${2:?}" current_handler
  current_handler="$(trap::_print_handler "$signal")"
  if [[ -n "$current_handler" ]]; then
    trap -- "${new_handler};${current_handler}" "$signal"
  else
    trap -- "$new_handler" "$signal"
  fi
}

trap::restore_handler() {
  # 退避したハンドラを復元する
  # 退避時に未設定だったシグナルはハンドラを解除する
  local signal

  if (( ${#_TRAP_STORE[@]} == 0 )); then
    core::warn 'no saved handler'
    return 0
  fi

  for signal in "${!_TRAP_STORE[@]}"; do
    if [[ -n "${_TRAP_STORE[${signal}]}" ]]; then
      trap -- "${_TRAP_STORE[${signal}]}" "$signal"
    else
      trap -- - "$signal"
    fi
  done

  _TRAP_STORE=()
  return 0
}
