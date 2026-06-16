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

# タイムスタンプを付与
: "${LOG_TS:=0}"

# スタックトレース設定
: "${LOG_TRACE_FATAL:=1}"
: "${LOG_TRACE_ERROR:=1}"
: "${LOG_TRACE_WARN:=0}"
: "${LOG_TRACE_INFO:=0}"
: "${LOG_TRACE_DEBUG:=0}"

# ファイル名を絶対パスで出力
: "${LOG_ABSPATH:=0}"
: "${LOG_TRACE_ABSPATH:=1}"

# fatal関数でexit 1する
: "${LOG_FATAL_EXIT:=1}"

log::_fmt_filename() {
  local f="$1" filename filepath

  filepath="$(realpath -- "$f")"
  filename="$(basename -- "$filepath")"

  if [[ ! -f "$filepath" ]]; then
    core::error "no such file or directory: ${filepath}"
    return 1
  fi

  if
    (
      [[ "${FUNCNAME[1]}" == 'log::_log_stacktrace' ]] && (( LOG_TRACE_ABSPATH ))
    ) || (
      [[ "${FUNCNAME[1]}" == 'log::_log_emit' ]] && (( LOG_ABSPATH ))
    )
  then
    printf '%s' "$filepath"
  else
    printf '%s' "$filename"
  fi
}

log::_log_emit() {
  local level="$1" style="$2" brief="$3"; shift 3
  local line file fmt_file

  read -r line _ file < <(caller 1)
  fmt_file="$(log::_fmt_filename "$file")"

  if (( brief )); then
    fmg_file=
    line=
  fi

  if (( LOG_TS )); then
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
  while read -r line subroutine file < <(caller "$i"); do
    fmt_file="$(log::_fmt_filename "$file")"
    printf '  #%d %s (%s)\n' \
      "$i" \
      "${STYLE_STDERR['log_stacktrace_function']:-}${subroutine}${STYLE_STDERR['rst']:-}" \
      "${STYLE_STDERR['log_stacktrace_location']:-}${fmt_file}:${line}${STYLE_STDERR['rst']:-}" >&2
    i=$((++i))
  done
}

log::_caller_libname() {
  # 0: log::_caller_libname
  # 1: log::_should_output_log
  # 2: logger
  # 3: 呼び出し元

  local libname="${BASH_SOURCE[3]:-}"
  libname="${libname##*/}"      # path/to/foo-bar.sh -> foo-bar.sh
  libname="${libname%.sh}"      # foo-bar.sh -> foo-bar
  libname="${libname//-/_}"     # foo-bar -> foo_bar
  libname="${libname^^}"        # foo_bar -> FOO_BAR

  echo "$libname"
}

log::_is_truthy() {
  local log_level="$1"
  local log_level_var="$2"
  local value

  if [[ -n "${!log_level_var+defined}" ]]; then
    value="${!log_level_var}"
  else
    # loggerの表示レベルが設定されていない(未定義or空)場合true
    return 0
  fi

  # 表示しようとしているログレベル log_level が
  # loggerの表示レベル value より大きければtrue、そうでなければfalse
  if (( value >= 0 && log_level >= value )); then
    return 0
  else
    return 1
  fi
}

log::_should_output_log() {
  local level_num="$1"
  local ch="${2:-}"
  local lib var

  # 0: log::_should_output_log
  # 1: logger
  # 2: caller
  lib="${BASH_SOURCE[2]:-}"
  lib="${lib##*/}"      # path/to/foo-bar.sh -> foo-bar.sh
  lib="${lib%.sh}"      # foo-bar.sh -> foo-bar
  lib="${lib//-/_}"     # foo-bar -> foo_bar
  lib="${lib^^}"        # foo_bar -> FOO_BAR

  if [[ -n "$ch" ]]; then
    ch="${ch//-/_}"
    ch="${ch^^}"
    var="LOG_LEVEL_${lib}_${ch}"

    log::_is_truthy "$level_num" "$var" || return 1
  fi

  var="LOG_LEVEL_${lib}"
  log::_is_truthy "$level_num" "$var" || return 1

  # root logger
  log::_is_truthy "$level_num" 'LOG_LEVEL' || return 1

  return 0
}

logger() {
  # Log Level Config
  #   ルートレベル、ファイルレベル、チャンネルレベルで指定可能。
  #   前述の順に優先されます。
  #
  #   ルートレベル:
  #     `LOG_LEVEL` で指定。
  #
  #   ファイルレベル:
  #     `LOG_LEVEL_<FILENAME>` で指定。
  #     `test.sh` のログレベルを指定する場合は、`LOG_LEVEL_TEST=3` のように指定します。
  #
  #   チャンネルレベル:
  #     logger実行時にチャンネルを指定できる。
  #     チャンネル指定のログは `LOG_LEVEL_<FILENAME>_<CH>` で指定されたレベルに従います。
  #     `test.sh` で実行した `logger --error --ch='testch' 'message'` を表示させる場合、
  #     `LOG_LEVEL_TEST_TESTCH=3` のように指定します。

  local level level_num style stacktrace
  local brief=0 ch=

  while (( $# > 0 )); do
    case "$1" in
      --) shift; break ;;
      --fatal)
        level='FATAL'
        level_num=4
        style="${STYLE_STDERR['fatal']:-}"
        stacktrace="$LOG_TRACE_FATAL"
        ;;
      --error)
        level='ERROR'
        level_num=3
        style="${STYLE_STDERR['error']:-}"
        stacktrace="$LOG_TRACE_ERROR"
        ;;
      --warning)
        level='WARNING'
        level_num=2
        style="${STYLE_STDERR['warning']:-}"
        stacktrace="$LOG_TRACE_WARN"
        ;;
      --info)
        level='INFO'
        level_num=1
        style="${STYLE_STDERR['info']:-}"
        stacktrace="$LOG_TRACE_INFO"
        ;;
      --debug)
        level='DEBUG'
        level_num=0
        style="${STYLE_STDERR['debug']:-}"
        stacktrace="$LOG_TRACE_DEBUG"
        ;;
      -b|--brief) brief=1 ;;
      --ch | --ch=*)
        if [[ "$1" =~ ^--ch= ]]; then
          ch="${1#--ch=}"
        elif [[ -z "${2:-}" ]]; then
          core::error 'missing channel'
          return 1
        else
          ch="$2"
          shift
        fi
        ;;
      *) break ;;
    esac
    shift
  done

  if [[ -z "${level:-}" ]]; then
    core::error 'missing log level'
    return 1
  fi

  if ! log::_should_output_log "$level_num" "$ch"; then
    return 0
  fi

  log::_log_emit "$level" "$style" "$brief" "$@"

  if (( stacktrace )); then
    log::_log_stacktrace
  fi

  if [[ "$level" == 'FATAL' ]] && (( LOG_FATAL_EXIT )); then
    exit 1
  fi
}
