# shellcheck shell=bash

# theme より下層のライブラリ(escseq, theme 自身)からも logger を使えるよう、
# log は theme に依存しない。スタイルは theme::load が入れるまで空のままで、
# 色が付かないだけで出力はできる。declare -gA の再宣言では中身は消えない。
#
# いずれもライブラリの外から参照されるグローバル連想配列。
# shellcheck disable=SC2034
declare -gA STYLE STYLE_ERR

# ログレベル
#   5: FATAL    スクリプトの停止を伴う致命的なエラー
#   4: ERROR    機能が満たされない可能性がある、致命的ではないエラー
#   3: WARN     潜在的な問題の警告
#   2: NOTICE   異常ではないが、重要なイベント
#   1: INFO     一般的な運用上のメッセージ
#   0: DEBUG    開発に必要な情報
#  -1: OFF      ログ出力無効
# 指定のレベル以上のログは出力されます。
# 負の値を設定することで、ログ出力を完全に抑制します。
: "${LOG_LEVEL:=1}"

# ログ行に表示する内容
: "${LOG_SHOW_TS:=0}"
: "${LOG_SHOW_FILE:=1}"
: "${LOG_SHOW_FUNC:=1}"
: "${LOG_SHOW_CH:=1}"

# スタックトレースを出すレベル
: "${LOG_STACKTRACE_FATAL:=1}"
: "${LOG_STACKTRACE_ERROR:=1}"
: "${LOG_STACKTRACE_WARN:=0}"
: "${LOG_STACKTRACE_NOTICE:=0}"
: "${LOG_STACKTRACE_INFO:=0}"
: "${LOG_STACKTRACE_DEBUG:=0}"

# ファイル名を絶対パスで出力
#   前者はログ行 (LOG_SHOW_FILE=1 のとき)、後者はスタックトレースに効く。
: "${LOG_ABSPATH:=0}"
: "${LOG_STACKTRACE_ABSPATH:=1}"

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
  # format: <timestamp> [<log level>] <meta>: <body>
  # meta format: <filename> <subroutine> [<ch>]

  local level="$1" style_level="$2" brief="$3" ch="$4"; shift 4
  local style_ts="${STYLE_ERR[log_timestamp]:-}" rst="${STYLE_ERR[rst]:-}"
  local line subroutine file fmt_file level_field
  local section_ts section_level section_meta
  local -a meta=() # メタ情報は区切りを持たせずに集め、最後にまとめて繋ぐ。

  # タイムスタンプ
  if (( LOG_SHOW_TS )); then
    # date(1) のフォークを避けてビルトインで組み立てる。%z は +0900 の形で
    # 出るため、date -Iseconds と同じ +09:00 に直す。
    local date
    TZ='JST-9' printf -v date '%(%FT%T%z)T' -1
    date="${date%??}:${date: -2}"
    section_ts="${style_ts}${date}${rst} "
  fi

  # ログレベル
  # レベルは最長の NOTICE に合わせて6桁の右詰めにする。
  # 色を付ける前に詰めないと、エスケープシーケンスの分だけ桁がずれる。
  printf -v level_field '%6s' "$level"
  section_level="[${style_level}${level_field}${rst}]"

  # メタデータ
  section_meta=
  # `bash -c` の直下のように caller が何も返さない場合がある。read は EOF で
  # 非ゼロを返すため、受け流さないと set -e の下でシェルごと落ちる。
  read -r line subroutine file < <(caller 1) || true
  if (( LOG_SHOW_FILE )) && [[ -n "$file" ]]; then
    fmt_file="$(log::_fmt_filename "$file" "$LOG_ABSPATH")"
    meta+=( "${style_level}${fmt_file}:${line}${rst}" )
  fi
  if (( LOG_SHOW_FUNC )) && [[ -n "$subroutine" && "$subroutine" != 'main' ]]; then
    meta+=( "${style_level}${subroutine}${rst}" )
  fi
  if (( LOG_SHOW_CH )) && [[ -n "$ch" ]]; then
    meta+=( "${style_level}[${ch}]${rst}" )
  fi
  if (( brief )); then
    meta=()
  fi
  if (( ${#meta[@]} )); then
    local IFS=' '
    section_meta=" ${meta[*]}:"
  fi

  # 本文
  # 色が無効なときは style_level が空文字になる。
  # 空のまま rst を付けると余計なリセットが1つ出るので掛けるときだけ囲む。
  local body="$*"
  [[ -n "$style_level" ]] && body="${style_level}${body}${rst}"

  printf '%s%s%s %s\n' \
    "${section_ts:-}" \
    "$section_level" \
    "$section_meta" \
    "$body" >&2
}

log::_log_stacktrace() {
  local i=1 line subroutine file fmt_file

  printf 'stacktrace:\n' >&2

  while read -r line subroutine file < <(caller "$i"); do
    fmt_file="$(log::_fmt_filename "$file" "$LOG_STACKTRACE_ABSPATH")"
    # 色を付けるのは位置だけ。関数名は地の色のまま残して、追いたい行を
    # 1色で拾えるようにする。
    printf '    at %s(%s)\n' \
      "$subroutine" \
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
  #     `foo.sh` のログレベルを指定する場合は、`LOG_LEVEL_FOO=3` のように指定します。
  #
  #   チャンネルレベル:
  #     logger実行時にチャンネルを指定できる。
  #     チャンネル指定のログは `LOG_LEVEL_<FILENAME>_<CH>` で指定されたレベルに従います。
  #     `foo.sh` で実行した `logger --error --ch='fooch' 'message'` を表示させる場合、
  #     `LOG_LEVEL_FOO_FOOCH=3` のように指定します。
  #     `LOG_LEVEL_FOO_FOOCH=-1` とすれば、そのチャンネルだけ出力が無効になります。

  local level level_num style stacktrace
  local brief=0 ch=

  while (( $# > 0 )); do
    case "$1" in
      --) shift; break ;;
      --fatal)
        level='FATAL'
        level_num=5
        style="${STYLE_ERR[log_fatal]:-}"
        stacktrace="$LOG_STACKTRACE_FATAL"
        ;;
      --error)
        level='ERROR'
        level_num=4
        style="${STYLE_ERR[log_error]:-}"
        stacktrace="$LOG_STACKTRACE_ERROR"
        ;;
      --warn | --warning)
        level='WARN'
        level_num=3
        style="${STYLE_ERR[log_warn]:-}"
        stacktrace="$LOG_STACKTRACE_WARN"
        ;;
      --notice)
        level='NOTICE'
        level_num=2
        style="${STYLE_ERR[log_notice]:-}"
        stacktrace="$LOG_STACKTRACE_NOTICE"
        ;;
      --info)
        level='INFO'
        level_num=1
        style="${STYLE_ERR[log_info]:-}"
        stacktrace="$LOG_STACKTRACE_INFO"
        ;;
      --debug)
        level='DEBUG'
        level_num=0
        style="${STYLE_ERR[log_debug]:-}"
        stacktrace="$LOG_STACKTRACE_DEBUG"
        ;;
      -b|--brief) brief=1 ;;
      --ch=*)
        set -- '--ch' "${1#*=}" "${@:2}"
        continue
        ;;
      -c|--ch)
        (( $# >= 2 )) || { logger --error 'missing channel'; return 1; }
        ch="$2"
        shift
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

  if [[ "$level" == 'FATAL' ]]; then
    exit 1
  fi
}
