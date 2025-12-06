#!/usr/bin/env bash

: LIBRARY METADATA
# shellcheck disable=SC2034
{
  LIB_VERSION='1.0.0'
  LIB_DEPS=( esc )
  [[ "${1:-}" = '__META_PROBE__' ]] && return 0
}

# ログにタイムスタンプを付与 (true/false)
: "${LOG_TS:=false}"

# ログのファイル名をフルパスで出力 (true/false)
: "${LOG_FULLPATH:=true}"

# stacktraceの出力設定 (true/false)
# トレース情報のファイル名をフルパスで出力
: "${LOG_TRACE_FULLPATH:=true}"
# ログレベルごとのトレース情報を出力の有無
: "${LOG_TRACE_ERROR:=true}"
: "${LOG_TRACE_WARN:=false}"
: "${LOG_TRACE_INFO:=false}"
: "${LOG_TRACE_DEBUG:=false}"

# abort関数の終了をreturn 1で行う (デフォルトではexit 1)
: "${LOG_ABORT_RETURN_ONLY:=false}"

log::_log_fmt_file() {
  local f="$1" file_dir file_fullpath

  file_dir="$(cd -- "${f%/*}" 2>/dev/null && pwd)"
  file_fullpath="${file_dir}/${f##*/}"

  if ! [[ -d "$file_dir" && -f "$file_fullpath" ]]; then
    echo "log.sh: no such file or directory: ${file_fullpath}" >&2
    return 1
  fi

  if [[ "${FUNCNAME[1]}" == 'log::_log_stacktrace' && \
        "$LOG_TRACE_FULLPATH" == 'true' ]] || \
     [[ "${FUNCNAME[1]}" == 'log::_log_emit' && \
        "$LOG_FULLPATH" == 'true' ]]
  then
    printf '%s' "$file_fullpath"
  else
    printf '%s' "${f##*/}"
  fi
}

log::_log_stacktrace() {
  local i=1 line func file fmt_file
  printf 'stacktrace:\n' >&2
  while read -r line func file _ < <(caller "$i"); do
    fmt_file="$(log::_log_fmt_file "$file")"
    printf '  #%d %s (%s)\n' \
      "$i" \
      "${ESC_STDERR_ATTR_BOLD}${ESC_TAG_STDERR_MAIN}${func}${ESC_STDERR_RESET}" \
      "${ESC_STDERR_FG_GRAY}${fmt_file}:${line}${ESC_STDERR_RESET}" >&2
    i=$((++i))
  done
}

log::_log_emit() {
  local level="$1" color="$2"; shift 2
  local line file fmt_file
  read -r line _ file _ < <(caller 1)
  fmt_file="$(log::_log_fmt_file "$file")"
  if [[ "$LOG_TS" == 'true' ]]; then
    printf '%s [%s] %s: line %s: %s\n' \
      "$(TZ='JST-9' date -Iseconds)" \
      "${color}${level}${ESC_STDERR_RESET}" \
      "$fmt_file" \
      "$line" \
      "$*" >&2
  else
    printf '%s: %s: line %s: %s\n' \
      "${ESC_STDERR_ATTR_BOLD}${color}${level}${ESC_STDERR_RESET}" \
      "$fmt_file" \
      "$line" \
      "$*" >&2
  fi
}

log.error() {
  log::_log_emit 'ERROR' "$ESC_STDERR_FG_RED" "$*"
  if [[ "$LOG_TRACE_ERROR" == 'true' ]]; then log::_log_stacktrace; fi
}

log.warn() {
  log::_log_emit 'WARN' "$ESC_STDERR_FG_YELLOW" "$*"
  if [[ "$LOG_TRACE_WARN" == 'true' ]]; then log::_log_stacktrace; fi
}

log.info() {
  log::_log_emit 'INFO' "$ESC_STDERR_FG_BLUE" "$*"
  if [[ "$LOG_TRACE_INFO" == 'true' ]]; then log::_log_stacktrace; fi
}

log.debug() {
  log::_log_emit 'DEBUG' "$ESC_STDERR_FG_GRAY" "$*"
  if [[ "$LOG_TRACE_DEBUG" == 'true' ]]; then log::_log_stacktrace; fi
}

abort() {
  log::_log_emit 'ABORT' "$ESC_STDERR_FG_RED" "$*"
  log::_log_stacktrace
  if [[ "${LOG_ABORT_RETURN_ONLY:-false}" == 'true' ]]; then
    return 1
  else
    exit 1
  fi
}
