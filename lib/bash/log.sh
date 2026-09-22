# shellcheck shell=bash

# theme より下層のライブラリ(escseq, theme 自身)からも logger を使えるよう、
# log は theme に依存しない。スタイルは theme::load が入れるまで空のままで、
# 色が付かないだけで出力はできる。declare -gA の再宣言では中身は消えない。
#
# いずれもライブラリの外から参照されるグローバル連想配列。
# shellcheck disable=SC2034
declare -gA STYLE STYLE_ERR

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

# ログに表示する内容を変更
: "${LOG_INFO_TS:=0}"
: "${LOG_INFO_FILE:=1}"
: "${LOG_INFO_CH:=1}"
: "${LOG_INFO_FUNC:=1}"

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

# チャンネル指定のログを非表示
: "${LOG_DISABLE_CH:=0}"

log::_fmt_filename() {
  # usage: log::_fmt_filename <ファイルパス> <絶対パス表示on,off(1,0)>
  local f="$1" abspath="$2"
  if (( abspath )); then
    realpath -- "$f"
  else
    printf '%s' "${f##*/}"
  fi
}

log::_log_emit() {
  local level="$1" style_level="$2" brief="$3" ch="$4"; shift 4
  local line file subroutine fmt_file

  read -r line subroutine file < <(caller 1)
  fmt_file="$(log::_fmt_filename "$file" "$LOG_ABSPATH")"

  local style_ts="${STYLE_ERR[log_timestamp]:-}"
  local style_ch="${STYLE_ERR[log_ch]:-}"
  local style_file="${STYLE_ERR[log_filename]:-}"
  local style_func="${STYLE_ERR[log_funcname]:-}"
  local rst="${STYLE_ERR[rst]:-}"
  local date section_ts section_level section_func section_file section_ch

  if (( LOG_INFO_TS )); then
    # date(1) のフォークを避けてビルトインで組み立てる。%z は +0900 の形で
    # 出るため、date -Iseconds と同じ +09:00 に直す。
    TZ='JST-9' printf -v date '%(%FT%T%z)T' -1
    date="${date%??}:${date: -2}"
    section_ts="${style_ts}${date}${rst}"
    section_level=" [${style_level}${level}${rst}]"
  else
    section_level="${style_level}${level}${rst}:"
  fi

  if (( LOG_INFO_FILE && LOG_INFO_CH )); then
    section_file=" ${style_file}${fmt_file}:${line}${rst}"
    section_ch="${ch:+[${style_ch}${ch}${rst}]} -"
  elif (( LOG_INFO_FILE )); then
    section_file=" ${style_file}${fmt_file}:${line}${rst} -"
  elif (( LOG_INFO_CH )); then
    section_ch="${ch:+ ${style_ch}${ch}${rst} -}"
  fi

  if (( LOG_INFO_FUNC )); then
    section_func=" ${style_func}${subroutine}${rst}:"
  fi

  if (( brief )); then
    section_file=
    section_ch=
    section_func=
  fi

  printf '%s%s%s%s%s %s\n' \
    "${section_ts:-}" \
    "$section_level" \
    "${section_file:-}" \
    "${section_ch:-}" \
    "${section_func:-}" \
    "$*" >&2
}

log::_log_stacktrace() {
  local i=1 line subroutine file fmt_file
  while read -r line subroutine file < <(caller "$i"); do
    fmt_file="$(log::_fmt_filename "$file" "$LOG_TRACE_ABSPATH")"
    printf '  #%d %s (%s)\n' \
      "$i" \
      "${STYLE_ERR[log_stacktrace_function]:-}${subroutine}${STYLE_ERR[rst]:-}" \
      "${STYLE_ERR[log_stacktrace_location]:-}${fmt_file}:${line}${STYLE_ERR[rst]:-}" >&2
    i=$(( i + 1 ))
  done
}

log::_ge_level() {
  # usage: log::_ge_level <ログレベル(数値)> <ログレベル(値を持つ変数名)>
  local log_level="$1"
  local value="${!2}"
  (( value >= 0 && log_level >= value ))
}

log::_should_output_log() {
  local level_num="$1"
  local ch="${2:-}"
  local lib var
  local -a candidates=()

  # ファイル別ログレベルの解決に使うファイル名は呼び出し元のスタック位置から
  # 求める。そのため logger をラップする関数を挟むと、ラッパーのファイル名で
  # 解決されてしまう点に注意。
  #
  # 0: log::_should_output_log
  # 1: logger
  # 2: caller
  lib="${BASH_SOURCE[2]:-}"
  lib="${lib##*/}"      # path/to/foo-bar.sh -> foo-bar.sh
  lib="${lib%.sh}"      # foo-bar.sh -> foo-bar
  lib="${lib//-/_}"     # foo-bar -> foo_bar
  lib="${lib^^}"        # foo_bar -> FOO_BAR

  if [[ -n "$ch" ]]; then
    (( LOG_DISABLE_CH )) && return 1
    ch="${ch//-/_}"
    ch="${ch^^}"
    candidates+=( "LOG_LEVEL_${lib}_${ch}" )
  fi
  candidates+=( "LOG_LEVEL_${lib}" 'LOG_LEVEL' )

  # チャンネル別、ファイル別、ルートの順に見て、最初に定義されているものに従う。
  for var in "${candidates[@]}"; do
    [[ -v "$var" ]] || continue
    log::_ge_level "$level_num" "$var"
    return
  done
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
        style="${STYLE_ERR[fatal]:-}"
        stacktrace="$LOG_TRACE_FATAL"
        ;;
      --error)
        level='ERROR'
        level_num=3
        style="${STYLE_ERR[error]:-}"
        stacktrace="$LOG_TRACE_ERROR"
        ;;
      --warning)
        level='WARNING'
        level_num=2
        style="${STYLE_ERR[warning]:-}"
        stacktrace="$LOG_TRACE_WARN"
        ;;
      --info)
        level='INFO'
        level_num=1
        style="${STYLE_ERR[info]:-}"
        stacktrace="$LOG_TRACE_INFO"
        ;;
      --debug)
        level='DEBUG'
        level_num=0
        style="${STYLE_ERR[debug]:-}"
        stacktrace="$LOG_TRACE_DEBUG"
        ;;
      -b|--brief) brief=1 ;;
      -c|--ch|--ch=*)
        if [[ "$1" =~ ^--ch= ]]; then
          ch="${1#--ch=}"
        elif [[ -z "${2:-}" ]]; then
          logger --error 'missing channel'
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
    logger --error 'missing log level'
    return 1
  fi

  if ! log::_should_output_log "$level_num" "$ch"; then
    return 0
  fi

  log::_log_emit "$level" "$style" "$brief" "$ch" "$@"

  if (( stacktrace )); then
    log::_log_stacktrace
  fi

  if [[ "$level" == 'FATAL' ]] && (( LOG_FATAL_EXIT )); then
    exit 1
  fi
}
