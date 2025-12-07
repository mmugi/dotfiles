#!/usr/bin/env bash

: LIBRARY METADATA
# shellcheck disable=SC2034
{
  LIB_VERSION='1.0.0';
  LIB_DEPS=( esc trap log )
  [[ "${1:-}" = '__META_PROBE__' ]] && return 0;
}

if (( "${BASH_VERSINFO[0]}" < 4 )) || \
   (( "${BASH_VERSINFO[0]}" == 4 && "${BASH_VERSINFO[1]}" < 1 ))
then
  printf 'error: %s: this script requires bash 4.1 or newer.\n' "${BASH_SOURCE[0]}" >&2
  exit 1
fi

if [[ -t 1 ]]; then
  : "${MSG_DELAY:=0.1}"
else
  MSG_DELAY=0
fi

: "${MSG_PROMPT_CHAR:=>}"
: "${MSG_C_BASE:=$ESC_TAG_BASE}"
: "${MSG_C_HIGHLIGHT1:=$ESC_TAG_MAIN}"
: "${MSG_C_HIGHLIGHT2:=$ESC_TAG_ACCENT2}"

_MSG_EXEC_TMPFILE_STDOUT="$(mktemp)"
_MSG_EXEC_TMPFILE_STDERR="$(mktemp)"

msg::_cleanup() {
  rm -f -- "$_MSG_EXEC_TMPFILE_STDOUT"
  rm -f -- "$_MSG_EXEC_TMPFILE_STDERR"
}

trap::concat 'EXIT' 'msg::_cleanup'
trap::concat 'TERM' 'msg::_cleanup'
trap::concat 'INT'  'msg::_cleanup'
trap::concat 'HUP'  'msg::_cleanup'

msg::_check_tty_mode() {
  if [[ -t 1 ]]; then
    : "${MSG_TTY_MODE:=true}"
  else
    MSG_TTY_MODE=false
  fi
}

newline() { printf '\n'; }

msg() {
  # スクリプトのメッセージ出力に利用できます。
  # 引数にとった文字列をオプションに基づいて整形・色付けして出力します。
  # 引数に取る文字列は以下のタグを解釈します。
  #   <hl>...</hl>: 囲まれた範囲の文字をプロンプトと同様の色でハイライトする
  #   <b>...</b>: 囲まれた範囲の文字を強調する
  #
  # options:
  #   -2   インデントされた出力を行います。
  #          $ msg example1; msg -2 example2
  #          > example1
  #            > example2
  #
  #   -b, --bold
  #        太文で出力します。
  #
  #   -c, --color <ansi color code>
  #        ベースの文字列色をANSI color codeで指定します。
  #        hlタグやプロンプト色には影響しません。
  #
  #   -n   末尾で改行しません。
  #
  #   -p, --progress
  #        末尾で処理中を示すプログレスドットを出力します。
  #          > example...
  #
  #   -P, --plain
  #        プロンプト非表示・文字色なしで出力します。
  #
  #   -r   \rで出力行をリセット後にメッセージを出力する。
  #
  #   -s, --spinner
  #        --progressオプションを有効化し、スピナー行を出力します。
  #        実行プロセスをkillするまで無限ループで出力し続けます。
  #
  #        使用例:
  #          バックグラウンド等で実行し、任意の処理実行後にtrap等でkillする
  #          msg::exec() などを参考にしてください。
  #            $ msg -s &
  #            ⠧ wait...
  #
  #   --ok, --ng, --result
  #        指定の結果文字列をプログレスドットのあとに出力します。
  #        オプションごとにカラーが異なります。
  #        --ok: blue
  #        --ng: red
  #        --result: hlタグと同様のカラー
  #
  #          $ msg --result EXAMPLE -- "message"
  #          > message...EXAMPLE
  #
  #   --prompt-char
  #        プロンプトの文字を指定します。指定されない場合は、
  #        環境変数 MSG_PROMPT_CHAR で指定された文字列を利用します。
  #          $ msg --prompt-char='#' -- message
  #          # message

  local bold result_str result_color

  local prompt_char="$MSG_PROMPT_CHAR"
  local prompt_color="$MSG_C_HIGHLIGHT1"
  local hl_color="$MSG_C_HIGHLIGHT1"
  local base_color="$MSG_C_BASE"

  local -r dots='...'
  #local -r spinner_dot='⠧⠏⠛⠹⠼⠶'
  #local -r spinner_line='/-\|'
  local -r spinner_star='-+*+-'
  local spinner_chars="$spinner_star"
  local spinner=false

  local line_reset=false
  local newline=true
  local progress_dots=false
  local style_plain=false

  while (( $# > 0 )); do
    case "$1" in
      --) shift; break ;;
      -2)
        hl_color="$MSG_C_HIGHLIGHT2"
        prompt_color="$MSG_C_HIGHLIGHT2"
        prompt_char=' >'
        ;;
      -b | --bold) bold="$ESC_ATTR_BOLD" ;;
      -c | --color | --color=*)
        if [[ "$1" =~ ^--color= ]]; then
          base_color="${1#--color=}"
        elif [[ -z "$2" ]]; then
          log.error "$1: expected a ansi color code"
          return 1
        elif [[ "$2" =~ ^-+ ]]; then
          log.error "$1: expected a ansi color code. perhaps try --color=\"$2\"?"
          return 1
        else
          base_color="$2"
          shift
        fi
        ;;
      -n) newline=false ;;
      -p | --progress)
        progress_dots=true
        line_reset=true
        ;;
      -P | --plain) style_plain=true ;;
      -r) line_reset=true ;;
      -s | --spinner)
        # 無限ループするので呼び出し側でkillが必要です
        progress_dots=true
        spinner=true
        newline=false
        ;;
      --ok | --ok=*)
        if [[ "$1" =~ ^--ok= ]]; then
          result_str="${1#--ok=}"
        elif [[ -z "$2" ]]; then
          log.error "$1: expected a string argument"
          return 1
        elif [[ "$2" =~ ^-+ ]]; then
          log.error "$1: expected a string argument. perhaps try --ok=\"$2\"?"
          return 1
        else
          result_str="$2"
          shift
        fi
        result_color="${ESC_ATTR_BOLD}${ESC_FG_BLUE}"
        ;;
      --ng | --ng=*)
        if [[ "$1" =~ ^--ng= ]]; then
          result_str="${1#--ng=}"
        elif [[ -z "$2" ]]; then
          log.error "$1: expected a string argument"
          return 1
        elif [[ "$2" =~ ^-+ ]]; then
          log.error "$1: expected a string argument. perhaps try --ng=\"$2\"?"
          return 1
        else
          result_str="$2"
          shift
        fi
        result_color="${ESC_ATTR_BOLD}${ESC_FG_RED}"
        ;;
      --result | --result=*)
        if [[ "$1" =~ ^--result= ]]; then
          result_str="${1#--result=}"
        elif [[ -z "$2" ]]; then
          log.error "$1: expected a string argument"
          return 1
        elif [[ "$2" =~ ^-+ ]]; then
          log.error "$1: expected a string argument. perhaps try --ok=\"$2\"?"
          return 1
        else
          result_str="$2"
          shift
        fi
        result_color="${ESC_ATTR_BOLD}${MSG_C_HIGHLIGHT1}"
        ;;
      --prompt-char | --prompt-char=*)
        if [[ "$1" =~ ^--prompt-char= ]]; then
          prompt_char="${1#--prompt-char=}"
        elif [[ -z "$2" ]]; then
          log.error "$1: expected a string argument"
          return 1
        elif [[ "$2" =~ ^-+ ]]; then
          log.error "$1: expected a string argument. perhaps try --prompt-char=\"$2\"?"
          return 1
        else
          prompt_char="$2"
          shift
        fi
        ;;
      -*) log.error "invalid option: $1"; return 1 ;;
      *) break ;;
    esac
    shift
  done

  msg::_check_tty_mode

  [[ $# -eq 0 ]] && { log.error 'message string is required'; return 1; }

  local msg prompt result
  local s="$*"

  if [[ "$style_plain" == 'true' ]]; then
    printf '%s' "$s"
  elif [[ "$MSG_TTY_MODE" == 'true' ]]; then
    s="${s//<hl>/${hl_color}}"
    s="${s//<\/hl>/${base_color}}"
    s="${s//<b>/${ESC_ATTR_BOLD}}"
    s="${s//<\/b>/${ESC_ATTR_RESET_IE}}"
    msg="${bold:-}${base_color}${s}"
    prompt="${prompt_color}${prompt_char} "
    result="${result_color:-}${result_str:-}"

    if [[ "$progress_dots" == 'true' ]]; then
      for (( i=0; i<=${#dots}; i++ )); do
        printf '\r\033[2K%s' "${prompt}${msg}${dots:0:i}${ESC_RESET}"
        sleep 0.1
      done
    fi

    if [[ "$spinner" == 'true' ]]; then
      local prompt_spinner
      local i=0
      local n="${#spinner_chars}"
      while true; do
        prompt_spinner="${prompt_color}${spinner_chars:i:1} "
        printf '\r\033[2K%s' "${prompt_spinner}${msg}${dots}${ESC_RESET}"
        i=$(( (i + 1) % n ))
        sleep 0.1
      done
    fi

    [[ "$line_reset" == 'true' ]] && printf '\r\033[2K'
    printf '%s' "${prompt}${msg}"
    if [[ -z "$result" ]]; then
      [[ "$progress_dots" == 'true' ]] && printf '%s' "$dots"
    else
      printf '%s' "${dots}${result}"
    fi
    printf '%s' "$ESC_RESET"
  else
    # stdout is not connected to a tty
    s="${s//<hl>/}"
    s="${s//<\/hl>/}"
    s="${s//<b>/}"
    s="${s//<\/b>/}"
    msg="$s"
    prompt=''
    result="${result_str:-}"
    if [[ -z "$result" ]]; then
      printf '%s' "${prompt}${msg}"
      [[ "$progress_dots" == 'true' ]] && printf '%s' "$dots"
    else
      printf '%s' "$result"
    fi
  fi

  [[ "$newline" == 'true' ]] && printf '\n'
  [[ "$MSG_TTY_MODE" == 'true' ]] && sleep "$MSG_DELAY"
  return 0
}

msg::complete() {
  msg -b --color="$ESC_FG_PINK" --prompt-char='✨️' "$*"
  printf '\n'
}

msg::warn() {
  msg -b --color="$ESC_FG_YELLOW" --prompt-char='⚡' "$*"
  printf '\n'
}

msg::exec() {
  local msg='wait'
  local result_ok='OK' result_ng='FAILED'
  local cmd kind spinner_pid

  msg::_check_tty_mode

  local _saved_abort_mode="$LOG_ABORT_RETURN_ONLY"
  LOG_ABORT_RETURN_ONLY=true

  local usage_oneline='usage: msg::exec [OPTION]... -- CMD'
  msg::_exec_usage() {
    cat <<EOF
$usage_oneline

コマンドの実行結果は、変数 MSG_EXEC_STDOUT, MSG_EXEC_STDERR に格納されます。

options:
  -h, --help                 show help
  -m, --msg, --msg="wait"    text to display while spinning
  --ok, --ok="OK"            message when command successfully
  --ng, --ng="FAILED"        message when command terminates abnormally
EOF
  }

  msg::_exec_spinner_stop() {
    if [[ -n "${spinner_pid:-}" ]]; then
      kill "$spinner_pid" 2>/dev/null ||:
      wait "$spinner_pid" 2>/dev/null ||:
      spinner_pid=
    fi
  }

  while (( $# > 0 )); do
    case "$1" in
      --) shift; break ;;
      -h | --help) msg::_exec_usage; return 0 ;;
      -m | --msg | --msg=*)
        if [[ "$1" =~ ^--msg= ]]; then
          msg="${1#--msg=}"
        elif [[ -z "$2" ]]; then
          log.error "$1: expected a string argument"
          return 1
        elif [[ "$2" =~ ^-+ ]]; then
          log.error "$1: expected a string argument. perhaps try --msg=\"$2\"?"
          return 1
        else
          msg="$2"
          shift
        fi
        ;;
      --ok | --ok=*)
        if [[ "$1" =~ ^--ok= ]]; then
          result_ok="${1#--ok=}"
        elif [[ -z "$2" ]]; then
          log.error "$1: expected a string argument"
          return 1
        elif [[ "$2" =~ ^-+ ]]; then
          log.error "$1: expected a string argument. perhaps try --ok=\"$2\"?"
          return 1
        else
          result_ok="$2"
          shift
        fi
        ;;
      --ng | --ng=*)
        if [[ "$1" =~ ^--ng= ]]; then
          result_ng="${1#--ng=}"
        elif [[ -z "$2" ]]; then
          log.error "$1: expected a string argument"
          return 1
        elif [[ "$2" =~ ^-+ ]]; then
          log.error "$1: expected a string argument. perhaps try --ng=\"$2\"?"
          return 1
        else
          result_ng="$2"
          shift
        fi
        ;;
      -*)
        log.error "invalid option: $1"
        return 1
        ;;
    esac
    shift
  done

  if (( $# <= 0 )); then
    echo "$usage_oneline" >&2
    return 1
  fi

  cmd="$1"
  kind="$(type -t -- "$cmd" ||:)"
  case "$kind" in
    file|builtin) ;;
    "") log.error "command not found: ${cmd}"; return 1 ;;
    *)  log.error "disallowd command type \"${kind}\": ${cmd}"; return 1 ;;
  esac

  trap::save_handler
  trap::concat 'EXIT' 'msg::_exec_spinner_stop'
  trap::concat 'TERM' 'msg::_exec_spinner_stop'
  trap::concat 'INT'  'msg::_exec_spinner_stop'
  trap::concat 'HUP'  'msg::_exec_spinner_stop'

  # start spinner
  msg --spinner "$msg" &
  spinner_pid=$!

  local rc=0
  "$@" >"$_MSG_EXEC_TMPFILE_STDOUT" 2>"$_MSG_EXEC_TMPFILE_STDERR" || rc=$?

  trap::restore_handler
  msg::_exec_spinner_stop

  LOG_ABORT_RETURN_ONLY="$_saved_abort_mode"

  if (( rc == 0 )); then
    msg -r --ok="$result_ok" "$msg"
    # [TODO] STDOUTの出力
  else
    msg -r --ng="$result_ng" "$msg"
    printf '%s\n' "$(cat "$_MSG_EXEC_TMPFILE_STDERR")" >&2
  fi

  return "$rc"
}
