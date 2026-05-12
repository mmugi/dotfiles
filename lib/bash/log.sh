# shellcheck shell=bash

LIB_VERSION='1.0.0'
LIB_DEPS=( core theme )
[[ "${1:-}" = '__IMPORT__' ]] && return 0

# ログレベル
#   4: FATAL    致命的なエラー、対応が必要
#   3: ERROR    一般的なエラー
#   2: WARN     知らせる必要があるが、必ずしも対応する必要がない事象
#   1: INFO     イベント
#   0: DEBUG    開発に必要な情報
#  -1: OFF      ログ無効
# 指定のレベル以上のログは出力されます。
# 負の値を設定することで、ログ出力を完全に抑制します。
: "${LOG_LEVEL:=1}"

# タイムスタンプを付与 (true/false)
: "${LOG_TS:=false}"

# スタックトレース設定 (true/false)
: "${LOG_TRACE_FATAL:=true}"
: "${LOG_TRACE_ERROR:=false}"
: "${LOG_TRACE_WARN:=false}"
: "${LOG_TRACE_INFO:=false}"
: "${LOG_TRACE_DEBUG:=false}"

# ファイル名を絶対パスで出力 (true/false)
: "${LOG_ABSPATH:=false}"
: "${LOG_TRACE_ABSPATH:=false}"

# fatal関数でexit 1する (falseを指定してreturn 1)
: "${LOG_FATAL_EXIT:=true}"

log::_fmt_filename() {
  local f="$1" filename filepath

  filepath="$(realpath -- "$f")"
  filename="$(basename -- "$filepath")"

  if [[ ! -f "$filepath" ]]; then
    core::error "no such file or directory: ${filepath}" >&2
    return 1
  fi

  if [[ \
        ( \
          "${FUNCNAME[1]}" == 'log::_log_stacktrace' \
            && "$LOG_TRACE_ABSPATH" == 'true' \
        ) || ( \
          "${FUNCNAME[1]}" == 'log::_log_emit' \
            && "$LOG_ABSPATH" == 'true' \
        ) \
     ]]
  then
    printf '%s' "$filepath"
  else
    printf '%s' "$filename"
  fi
}

log::_log_emit() {
  local level="$1" style="$2" verbose="$3"; shift 3
  local line file fmt_file

  if [[ "$verbose" == 'true' ]]; then
    read -r line _ file < <(caller 1)
    fmt_file="$(log::_fmt_filename "$file")"
  else
    line=
    fmt_file=
  fi

  if [[ "$LOG_TS" == 'true' ]]; then
    printf '%s [%s]%s%s %s\n' \
      "${STYLE_STDERR['log_timestamp']:-}$(TZ='JST-9' date -Iseconds)${STYLE_STDERR['rst']:-}" \
      "${style}${level}${STYLE_STDERR['rst']:-}" \
      "${fmt_file:+" ${fmt_file}:"}" \
      "${line:+" line ${line}:"}" \
      "$*" >&2
  else
    printf '%s%s%s %s\n' \
      "${style}${level}${STYLE_STDERR['rst']:-}:" \
      "${fmt_file:+" ${fmt_file}:"}" \
      "${line:+" line ${line}:"}" \
      "$*" >&2
  fi
}

log::_log_stacktrace() {
  local i=1 line subroutine file fmt_file
  printf 'stacktrace:\n' >&2
  while read -r line subroutine file _ < <(caller "$i"); do
    fmt_file="$(log::_fmt_filename "$file")"
    printf '  #%d %s (%s)\n' \
      "$i" \
      "${STYLE_STDERR['log_stacktrace_function']:-}${subroutine}${STYLE_STDERR['rst']:-}" \
      "${STYLE_STDERR['log_stacktrace_location']:-}${fmt_file}:${line}${STYLE_STDERR['rst']:-}" >&2
    i=$((++i))
  done
}

log::logger() {
  local level level_ts_fmt level_num style stacktrace
  local verbose=false

  while (( $# > 0 )); do
    case "$1" in
      --) shift; break ;;
      --fatal)
        level='FATAL'
        level_ts_fmt='FATAL'
        level_num=4
        style="${STYLE_STDERR['log_fatal']:-}"
        stacktrace="$LOG_TRACE_FATAL"
        ;;
      --error)
        level='ERROR'
        level_ts_fmt='ERR'
        level_num=3
        style="${STYLE_STDERR['log_error']:-}"
        stacktrace="$LOG_TRACE_ERROR"
        ;;
      --warn)
        level='WARN'
        level_ts_fmt='WRN'
        level_num=2
        style="${STYLE_STDERR['log_warn']:-}"
        stacktrace="$LOG_TRACE_WARN"
        ;;
      --info)
        level='INFO'
        level_ts_fmt='INF'
        level_num=1
        style="${STYLE_STDERR['log_info']:-}"
        stacktrace="$LOG_TRACE_INFO"
        ;;
      --debug)
        level='DEBUG'
        level_ts_fmt='DBG'
        level_num=0
        style="${STYLE_STDERR['log_debug']:-}"
        stacktrace="$LOG_TRACE_DEBUG"
        ;;
      -v|--verbose) verbose=true ;;
      *) break ;;
    esac
    shift
  done

  if [[ -z "${level:-}" ]]; then
    core::error 'missing log level'
    return 1
  fi

  if (( LOG_LEVEL > level_num || LOG_LEVEL < 0 )); then
    return 0
  fi

  if [[ "$LOG_TS" == 'true' ]]; then
    log::_log_emit "$level_ts_fmt" "$style" "$verbose" "$@"
  else
    log::_log_emit "$level" "$style" "$verbose" "$@"
  fi

  if [[ "$stacktrace" == 'true' ]]; then
    log::_log_stacktrace
  fi

  if [[ "$level" == 'FATAL' && "$LOG_FATAL_EXIT" == 'true' ]]; then
    exit 1
  fi
}
