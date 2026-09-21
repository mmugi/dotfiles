# shellcheck shell=bash

# @deps log theme

: "${MSG_PREFIX:=[>]}"
: "${MSG_PREFIX_HEADER:=###}"
: "${MSG_PREFIX_NOTICE:=[~]}"
: "${MSG_PREFIX_CHANGED:=[*]}"
: "${MSG_PREFIX_SKIPPED:=[=]}"
: "${MSG_PREFIX_OK:=[^]}"
: "${MSG_PREFIX_WARN:=[!]}"
: "${MSG_PREFIX_ERROR:=[x]}"
: "${MSG_PREFIX_CONFIRM:=[?]}"

msg::newline() { printf '\n'; }

msg() {
  # スクリプトのメッセージ出力に利用できます。
  # 引数にとった文字列を色付けし、行頭にプレフィックス (`[>]` など) を添えて
  # 標準出力へ出します。themeライブラリの `STYLE_STDOUT` を利用します。
  #
  # 一部だけ色を変えたい場合は、呼び出し側が `STYLE_STDOUT` を埋めて組み立てます。
  # base style はプレフィックス後に一度だけシーケンスを出力します。そのため、
  # 強調を終えるときは `rst` ではなく base のスタイルを出し直してください。
  #
  #     hl="${STYLE_STDOUT['msg_highlight']:-}"
  #     base="${STYLE_STDOUT['normal']:-}"
  #     msg "checking ${hl}${target}${base} command..."
  #
  #
  # 色が無効なとき `STYLE_STDOUT` は空になるため、同じ式のまま平文になります。
  #
  # 行末には必ず reset のシーケンスを出力します。呼び出し側が閉じ忘れても、
  # 次の行やシェルのプロンプトへ色が漏れないようにするためです。
  #
  # 入力に改行が含まれる場合は、行ごとにプレフィックスと base style を添えます。
  #
  # Options:
  #
  #   -n   末尾で改行しません。
  #
  #   -R, --readline
  #
  #        readline用に制御コードSOH, STXをエスケープシーケンスに付与します。
  #        `read -p` のプロンプトに渡す場合に必要です。
  #
  #   -s, --base-style <style>
  #
  #        本文のスタイル名を指定します。行ごとに適用されます。
  #
  #   --prefix <prefix string>
  #
  #        行頭のプレフィックス文字列を指定します。
  #
  #   --prefix-style <style>
  #
  #        プレフィックスのスタイル名を指定します。
  #
  #   --no-prefix
  #
  #        プレフィックスなしで出力します。

  local prefix="$MSG_PREFIX"
  local prefix_style='msg_prefix'
  local base_style='normal'
  local newline=1
  local readline=0

  while (( $# > 0 )); do
    case "$1" in
      --) shift; break ;;
      -n) newline=0 ;;
      -R | --readline) readline=1 ;;
      --no-prefix) prefix= ;;
      -s | --base-style | --base-style=*)
        if [[ "$1" == --base-style=* ]]; then
          base_style="${1#--base-style=}"
        elif (( $# < 2 )); then
          logger --error 'missing style name'
          return 1
        else
          base_style="$2"
          shift
        fi
        ;;
      --prefix | --prefix=*)
        if [[ "$1" == --prefix=* ]]; then
          prefix="${1#--prefix=}"
        elif (( $# < 2 )); then
          logger --error 'missing prefix string'
          return 1
        else
          prefix="$2"
          shift
        fi
        ;;
      --prefix-style | --prefix-style=*)
        if [[ "$1" == --prefix-style=* ]]; then
          prefix_style="${1#--prefix-style=}"
        elif (( $# < 2 )); then
          logger --error 'missing prefix style'
          return 1
        else
          prefix_style="$2"
          shift
        fi
        ;;
      -*) logger --error "invalid option: $1"; return 1 ;;
      *) break ;;
    esac
    shift
  done

  local rst="${STYLE_STDOUT['rst']:-}"
  local pstyle="${STYLE_STDOUT[${prefix_style}]:-}"
  local base="${STYLE_STDOUT[${base_style}]:-}"

  if (( readline )); then
    # read -p のプロンプトでは、エスケープシーケンスを SOH/STX で囲まないと
    # 表示幅に数えられ、行編集の位置がずれる。
    [[ -n "$rst" ]]    && rst=$'\x01'"${rst}"$'\x02'
    [[ -n "$pstyle" ]] && pstyle=$'\x01'"${pstyle}"$'\x02'
    [[ -n "$base" ]]   && base=$'\x01'"${base}"$'\x02'
  fi

  local head=''
  [[ -n "$prefix" ]] && head="${pstyle}${prefix}${rst} "

  local out='' line
  while IFS= read -r line; do
    out+="${head}${base}${line}${rst}"$'\n'
  done <<< "$*"

  (( newline )) || out="${out%$'\n'}"

  printf '%s' "$out"

  return 0
}

msg::header() {
  msg \
    --prefix="$MSG_PREFIX_HEADER" \
    --prefix-style='msg_header' \
    "$@"
}

msg::notice() {
  msg \
    --prefix="$MSG_PREFIX_NOTICE" \
    --prefix-style='msg_notice' \
    "$@"
}

msg::changed() {
  msg \
    --prefix="$MSG_PREFIX_CHANGED" \
    --prefix-style='msg_changed' \
    "$@"
}

msg::ok() {
  msg \
    --prefix="$MSG_PREFIX_OK" \
    --prefix-style='msg_ok' \
    "$@"
}

msg::warn() {
  msg \
    --prefix="$MSG_PREFIX_WARN" \
    --prefix-style='msg_warn' \
    "$@"
}

msg::error() {
  msg \
    --prefix="$MSG_PREFIX_ERROR" \
    --prefix-style='msg_error' \
    "$@"
}

msg::skipped() {
  msg \
    --prefix="$MSG_PREFIX_SKIPPED" \
    --prefix-style='msg_skipped' \
    "$@"
}

msg::read() {
  if [[ ! -t 0 ]]; then
    logger --error 'standard input is not a terminal'
    return 1
  fi

  local -a read_args=()
  local prompt_msg input

  while (( $# > 0 )); do
    case "$1" in
      --) shift; break ;;
      *) read_args+=( "$1" ) ;;
    esac
    shift
  done

  prompt_msg="$(
    msg -n -R \
    --prefix="$MSG_PREFIX_CONFIRM" \
    --prefix-style='msg_confirm' \
    -- "$*"
  )"

  IFS='' read -r "${read_args[@]}" -p "$prompt_msg" input
  printf '%s' "$input"
}

msg::confirm() {
  # usage: msg::confirm <質問>
  #
  # y / yes が入力されたら 0、n / no なら 1 を返します。
  # それ以外の入力は聞き直します。

  if [[ ! -t 0 ]]; then
    logger --error 'standard input is not a terminal'
    return 1
  fi

  if (( $# == 0 )); then
    logger --error 'missing question message'
    return 1
  fi

  local input

  while true; do
    msg -n \
      --prefix="$MSG_PREFIX_CONFIRM" \
      --prefix-style='msg_confirm' \
      -- "$* (y/n) " </dev/tty >/dev/tty

    # プロンプトが出る前に打たれていた先行入力を捨てる。無ければタイムアウトで
    # 非ゼロが返るが、異常ではないので無視(set -e の下で呼ばれた場合、ここで
    # 落ちてしまう)。
    read -sr -t 0.1 -N 255 _ || true

    IFS='' read -r input
    if [[ "$input" =~ ^([Yy]|[Yy][Ee][Ss])$ ]]; then
      return 0
    elif [[ "$input" =~ ^([Nn]|[Nn][Oo])$ ]]; then
      return 1
    else
      msg::warn 'invalid input:('
      continue
    fi
  done
}

msg::select() {
  if [[ ! -t 0 ]]; then
    logger --error 'standard input is not a terminal'
    return 1
  fi

  local -a msg_args=()
  local ps
  # PS3 と COLUMNS は select が参照する変数。関数を抜けたあとのシェルに
  # 影響を残さないよう local で宣言する (select は関数ローカルの値を見る)。
  local PS3 COLUMNS s

  while (( $# > 0 )); do
    case "$1" in
      --) shift; break ;;
      --ps | --ps=*)
        if [[ "${1:-}" =~ ^--ps= ]]; then
          ps="${1#--ps=}"
        elif [[ -z "${2:-}" ]]; then
          logger --error 'missing prompt'
          return 1
        else
          ps="$2"
          shift
        fi
        ;;
      -*) msg_args+=( "$1" ) ;;
      *)  break ;;
    esac
    shift
  done

  if [[ -n "${ps:-}" ]]; then
    PS3="$(msg --prefix="$MSG_PREFIX_CONFIRM" --prefix-style='msg_confirm' -- "$ps")"
  fi
  COLUMNS=1

  select s in "$@"; do
    [[ "$REPLY" =~ ^[Qq](uit)?$ ]] && return 1
    [[ -z "$s" ]] && continue
    printf '%s' "$s"
    break
  done
}
