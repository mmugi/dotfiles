#!/usr/bin/env bash

set -ueo pipefail

# shellcheck disable=SC2034
{
  LIB_VERSION='1.0.0'
  LIB_DEPS='esc'
  [[ ${1:-} = __META_PROBE__ ]] && return 0
}

: "${LOG_TS:=false}"              # true: タイムスタンプを出力
: "${LOG_FULLPATH:=false}"        # true: フルパス / false: ファイル名のみ
: "${LOG_TRACE_ERROR:=false}"     # true: error 時にスタックトレース出力
: "${LOG_TRACE_WARN:=false}"
: "${LOG_TRACE_INFO:=false}"
: "${LOG_TRACE_DEBUG:=false}"

_log_fmt_file() {
  local f="$1"
  if "$LOG_FULLPATH"; then
    printf '%s' "$(cd "${f%/*}"; pwd)/${f##*/}"
  else
    printf '%s' "${f##*/}"
  fi
}

_log_stacktrace() {
  local i=0 line func file
  printf 'stacktrace:\n'
  while read -r line func file _ < <(caller "$i"); do
    # lib自身をスキップ
    if [[ $file = "${BASH_SOURCE[0]}" || ${file##*/} = "${BASH_SOURCE[0]##*/}" ]]; then
      i=$((++i))
      continue
    fi
    printf "  #%d %s (%s)\n" \
      "$i" \
      "${ESC_ATTR_BOLD}${ESC_TAG_MAIN}$func${ESC_RESET}" \
      "${ESC_FG_GRAY}$(_log_fmt_file "$file"):${line}${ESC_RESET}"
    i=$((++i))
  done
}

_log_emit() {
  local level="$1" color="$2"; shift 2
  local line file
  read -r line _ file _ < <(caller 1)
  if "$LOG_TS"; then
    printf '%s [%s] %s: line %s: %s\n' \
      "$(TZ='JST-9' date -Iseconds)" \
      "${color}${level}${ESC_RESET}" \
      "$(_log_fmt_file "$file")" \
      "$line" \
      "$*" >&2
  else
    printf '%s: %s: line %s: %s\n' \
      "${ESC_ATTR_BOLD}${color}${level}${ESC_RESET}" \
      "$(_log_fmt_file "$file")" \
      "$line" \
      "$*" >&2
  fi
}

log.error() {
  _log_emit 'ERROR' "$ESC_FG_RED" "$*"
  if "$LOG_TRACE_ERROR"; then _log_stacktrace; fi
}

log.warn() {
  _log_emit 'WARN' "$ESC_FG_YELLOW" "$*"
  if "$LOG_TRACE_WARN"; then _log_stacktrace; fi
}

log.info() {
  _log_emit 'INFO' "$ESC_FG_BLUE" "$*"
  if "$LOG_TRACE_INFO"; then _log_stacktrace; fi
}

log.debug() {
  _log_emit 'DEBUG' "$ESC_FG_GRAY" "$*"
  if "$LOG_TRACE_DEBUG"; then _log_stacktrace; fi
}

abort() {
  _log_emit 'ABORT' "$ESC_FG_RED" "$*"
  _log_stacktrace
  exit 1
}
