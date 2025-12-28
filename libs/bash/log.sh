# shellcheck shell=bash
# shellcheck disable=SC2034
{
  LIB_VERSION='1.0.0'
  LIB_DEPS=( esc )
  [[ "${1:-}" = '__META_PROBE__' ]] && return 0
}

# ログにタイムスタンプを付与 (true/false)
: "${LOG_TS:=false}"

# ログのファイル名をフルパスで出力 (true/false)
: "${LOG_FULLPATH:=false}"

# ログの出力レベル
#   ERROR : 4
#   WARN  : 3
#   NOTICE: 2
#   INFO  : 1
#   DEBUG : 0
# 指定のレベル以上のログは出力されます。
# 負の値を設定することで、ログ出力を完全に抑制します。
: "${LOG_LEVEL:=1}"

# stacktraceの出力設定 (true/false)
# トレース情報のファイル名をフルパスで出力
: "${LOG_TRACE_FULLPATH:=true}"
# ログレベルごとのトレース情報を出力の有無
: "${LOG_TRACE_ERROR:=false}"
: "${LOG_TRACE_WARN:=false}"
: "${LOG_TRACE_NOTICE:=false}"
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
      "${ESC_STDERR_ATTR_BOLD}${ESC_C_STDERR_MAIN}${func}${ESC_STDERR_RESET}" \
      "${ESC_STDERR_GRAY}${fmt_file}:${line}${ESC_STDERR_RESET}" >&2
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

log::error() {
  (( LOG_LEVEL > 4 || LOG_LEVEL < 0 )) && return 0
  log::_log_emit 'ERROR' "$ESC_C_STDERR_CRITICAL" "$*"
  if [[ "$LOG_TRACE_ERROR" == 'true' ]]; then log::_log_stacktrace; fi
}

log::warn() {
  (( LOG_LEVEL > 3 || LOG_LEVEL < 0 )) && return 0
  log::_log_emit 'WARN' "$ESC_C_STDERR_WARNING" "$*"
  if [[ "$LOG_TRACE_WARN" == 'true' ]]; then log::_log_stacktrace; fi
}

log::notice() {
  (( LOG_LEVEL > 2 || LOG_LEVEL < 0 )) && return 0
  log::_log_emit 'NOTICE' "$ESC_C_NOTICE" "$*"
  if [[ "$LOG_TRACE_NOTICE" == 'true' ]]; then log::_log_stacktrace; fi
}

log::info() {
  (( LOG_LEVEL > 1 || LOG_LEVEL < 0 )) && return 0
  log::_log_emit 'INFO' "$ESC_C_STDERR_INFO" "$*"
  if [[ "$LOG_TRACE_INFO" == 'true' ]]; then log::_log_stacktrace; fi
}

log::debug() {
  (( LOG_LEVEL > 0 || LOG_LEVEL < 0 )) && return 0
  log::_log_emit 'DEBUG' "$ESC_C_STDERR_DEBUG" "$*"
  if [[ "$LOG_TRACE_DEBUG" == 'true' ]]; then log::_log_stacktrace; fi
}

abort() {
  log::_log_emit 'ABORT' "$ESC_C_STDERR_PANIC" "$*"
  log::_log_stacktrace
  if [[ "${LOG_ABORT_RETURN_ONLY:-false}" == 'true' ]]; then
    return 1
  else
    exit 1
  fi
}
