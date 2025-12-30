# shellcheck shell=bash
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
: "${MSG_INDENT:=0}"
: "${MSG_C_BASE:="$ESC_C_BASE"}"
: "${MSG_C_HIGHLIGHT1:="$ESC_C_MAIN"}"
: "${MSG_C_HIGHLIGHT2:="$ESC_C_ACCENT1"}"
: "${MSG_LOGO:-}"
: "${MSG_BOX_WIDTH:=80}"

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
  #
  # env:
  #   MSG_INDENT
  #        インデントの高さを数値で指定します(0でインデントなし)。
  #
  # tags:
  #   引数に取る文字列は以下のタグを解釈します。
  #     <hl>...</hl>: 囲まれた範囲の文字をプロンプトと同様の色でハイライトする
  #     <b>...</b>: 囲まれた範囲の文字を強調する
  #
  # options:
  #   -2   ハイライトカラーを変更します。
  #        セクションに応じて、使用します。
  #
  #   -b, --bold
  #        メッセージ本文を太字で出力します。
  #
  #   -B, --prompt-bold
  #        プロンプト文字を太字で出力します。
  #
  #   -c, --base-color <ansi color code>
  #        ベースの文字列色をANSI color codeで指定します。
  #        hlタグやプロンプト色には影響しません。
  #
  #   -C, --hl-color <ansi color code>
  #        <hl>タグのハイライト文字列色をANSI color codeで指定します。
  #
  #   -n   末尾で改行しません。
  #
  #   -p, --progress
  #        末尾で処理中を示すプログレスドットを出力します。
  #          > example...
  #
  #   -P, --plain
  #        プロンプト非表示かつバックスラッシュを解釈せずに出力します。
  #        タグの解釈も行いません。
  #        --stripオプションが指定された場合は、制御文字およびタグ文字の除去を
  #        行ったうえで出力されます。
  #
  #   -r   \rで出力行をリセット後にメッセージを出力する。
  #
  #   -R   強調表示およびランダムな絵文字プロンプトで出力します。
  #
  #   -s, --strip
  #       制御文字(ANSI, ASCII)およびタグの除去をして出力します。
  #
  #   --spinner
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
  #   --prompt
  #        プロンプトを指定します。
  #        指定されない場合は、環境変数 MSG_PROMPT_CHAR で指定された文字列を利用します。
  #          $ msg --prompt='#' -- message
  #          # message
  #
  #   --prompt-color <ansi color code>
  #        プロンプト文字列色をANSI color codeで指定します。
  #
  #   --no-prompt
  #        プロンプトなしで出力します。

  local prompt_bold prompt_str prompt_color
  local prompt_indent='' no_prompt=false
  local bold base_color hl_color
  local result_str result_color
  local p

  local -r dots='...'
  #local -r spinner_dot='⠧⠏⠛⠹⠼⠶'
  #local -r spinner_line='/-\|'
  local -r spinner_star='-+*+-'
  local spinner_chars="$spinner_star"
  local spinner=false

  local line_reset=false
  local newline=true
  local progress_dots=false
  local strip=false
  local style_plain=false

  while (( $# > 0 )); do
    case "$1" in
      --) shift; break ;;
      -2)
        hl_color="$MSG_C_HIGHLIGHT2"
        prompt_color="$MSG_C_HIGHLIGHT2"
        ;;
      -b | --bold) bold="$ESC_ATTR_BOLD" ;;
      -B | --prompt-bold) prompt_bold="$ESC_ATTR_BOLD" ;;
      -c | --base-color | --base-color=*)
        if [[ "$1" =~ ^--base-color= ]]; then
          base_color="${1#--base-color=}"
        elif [[ -z "${2:-}" ]]; then
          # stdoutがttyに接続されていない場合、escライブラリの
          # 色変数が空になる場合がある。
          shift
        elif [[ "$2" =~ ^-+ ]]; then
          log::error "$1: expected a ansi color code. perhaps try --base-color=\"$2\"?"
          return 1
        else
          base_color="$2"
          shift
        fi
        ;;
      -C | --hl-color | --hl-color=*)
        if [[ "$1" =~ ^--hl-color= ]]; then
          hl_color="${1#--hl-color=}"
        elif [[ -z "${2:-}" ]]; then
          # stdoutがttyに接続されていない場合、escライブラリの
          # 色変数が空になる場合がある。
          shift
        elif [[ "$2" =~ ^-+ ]]; then
          log::error "$1: expected a ansi color code. perhaps try --hl-color=\"$2\"?"
          return 1
        else
          hl_color="$2"
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
      -R)
        base_color="$MSG_C_HIGHLIGHT1"
        p="$(( RANDOM % 4 + 1 ))"
        case "$p" in
          1) prompt_str='🛸' ;;
          2) prompt_str='🛰️' ;;
          3) prompt_str='🚀' ;;
          4) prompt_str='🪐' ;;
        esac
        ;;
      -s | --strip) strip=true ;;
      --spinner)
        # 無限ループするので呼び出し側でkillが必要です
        progress_dots=true
        spinner=true
        newline=false
        ;;
      --ok | --ok=*)
        if [[ "$1" =~ ^--ok= ]]; then
          result_str="${1#--ok=}"
        elif [[ -z "${2:-}" ]]; then
          log::error "$1: expected a string argument"
          return 1
        elif [[ "$2" =~ ^-+ ]]; then
          log::error "$1: expected a string argument. perhaps try --ok=\"$2\"?"
          return 1
        else
          result_str="$2"
          shift
        fi
        result_color="${ESC_ATTR_BOLD}${ESC_C_SUCCESS}"
        ;;
      --ng | --ng=*)
        if [[ "$1" =~ ^--ng= ]]; then
          result_str="${1#--ng=}"
        elif [[ -z "${2:-}" ]]; then
          log::error "$1: expected a string argument"
          return 1
        elif [[ "$2" =~ ^-+ ]]; then
          log::error "$1: expected a string argument. perhaps try --ng=\"$2\"?"
          return 1
        else
          result_str="$2"
          shift
        fi
        result_color="${ESC_ATTR_BOLD}${ESC_C_FAILURE}"
        ;;
      --result | --result=*)
        if [[ "$1" =~ ^--result= ]]; then
          result_str="${1#--result=}"
        elif [[ -z "${2:-}" ]]; then
          log::error "$1: expected a string argument"
          return 1
        elif [[ "$2" =~ ^-+ ]]; then
          log::error "$1: expected a string argument. perhaps try --ok=\"$2\"?"
          return 1
        else
          result_str="$2"
          shift
        fi
        result_color="${ESC_ATTR_BOLD}${MSG_C_HIGHLIGHT1}"
        ;;
      --prompt | --prompt=*)
        if [[ "$1" =~ ^--prompt= ]]; then
          prompt_str="${1#--prompt=}"
        elif [[ -z "${2:-}" ]]; then
          log::error "$1: expected a string argument"
          return 1
        elif [[ "$2" =~ ^-+ ]]; then
          log::error "$1: expected a string argument. perhaps try --prompt=\"$2\"?"
          return 1
        else
          prompt_str="$2"
          shift
        fi
        ;;
      --prompt-color | --prompt-color=*)
        if [[ "$1" =~ ^--prompt-color= ]]; then
          prompt_color="${1#--prompt-color=}"
        elif [[ -z "${2:-}" ]]; then
          # stdoutがttyに接続されていない場合、escライブラリの
          # 色変数が空になる場合がある。
          shift
        elif [[ "$2" =~ ^-+ ]]; then
          log::error "$1: expected a ansi color code. perhaps try --prompt-color=\"$2\"?"
          return 1
        else
          prompt_color="$2"
          shift
        fi
        ;;
      --no-prompt) no_prompt=true ;;
      -*) log::error "invalid option: $1"; return 1 ;;
      *) break ;;
    esac
    shift
  done

  if [[ "$no_prompt" == 'true' ]]; then
    unset prompt_str
  else
    : "${prompt_str:="$MSG_PROMPT_CHAR"}"
  fi

  : "${prompt_color:="$MSG_C_HIGHLIGHT1"}"
  : "${hl_color:="$MSG_C_HIGHLIGHT1"}"
  : "${base_color:="$MSG_C_BASE"}"

  msg::_check_tty_mode

  [[ $# -eq 0 ]] && { log::error 'message string is required'; return 1; }

  local msg prompt result
  local s="$*"

  prompt_indent="$(printf '%*s' "$MSG_INDENT" '')"

  if [[ "$style_plain" == 'true' ]]; then
    s="${s//<hl>/}"
    s="${s//<\/hl>/}"
    s="${s//<b>/}"
    s="${s//<\/b>/}"
    msg="$s"
    prompt="${prompt_indent}${prompt_str:-}${prompt_str+ }"

    if [[ "$strip" == 'true' ]]; then
      printf '%s%s' "$prompt" "$msg" \
        | sed -E 's/\x1b\[[0-9;?]*[ -/]*[@-~]//g' \
        | tr -d '\000-\010\013\014\016-\037\177'
    else
      printf '%s%s' "$prompt" "$msg"
    fi
  elif [[ "$MSG_TTY_MODE" == 'true' ]]; then
    s="${s//<hl>/${hl_color}}"
    s="${s//<\/hl>/${base_color}}"
    s="${s//<b>/${ESC_ATTR_BOLD}}"
    s="${s//<\/b>/${ESC_ATTR_RESET_IE}}"
    msg="${bold:-${ESC_ATTR_RESET_IE}}${base_color}${s}"
    prompt="${prompt_bold:-${ESC_ATTR_RESET_IE}}${prompt_color}${prompt_indent}${prompt_str:-}${prompt_str+ }"
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
        prompt_spinner="${prompt_indent}${prompt_color}${spinner_chars:i:1} "
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
    prompt="${prompt_indent}${prompt_str:-}${prompt_str+ }"
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

msg::box() {
  local term_width box_width
  local box_color base_color base_color
  local prompt
  local line plain_text len max=0 max_logo=0
  local -a messages=() logo_lines=() opts_prompt=()
  local padding=2 top_padding=false mid_padding=false bot_padding=false
  local width_fit_mode=auto

  while (( $# > 0 )); do
    case "$1" in
      --) shift; break ;;
      -c | --base-color | --base-color=*)
        if [[ "$1" =~ ^--base-color= ]]; then
          base_color="${1#--base-color=}"
        elif [[ -z "${2:-}" ]]; then
          # stdoutがttyに接続されていない場合、escライブラリの
          # 色変数が空になる場合がある。
          shift
        elif [[ "$2" =~ ^-+ ]]; then
          log::error "$1: expected a ansi color code. perhaps try --base-color=\"$2\"?"
          return 1
        else
          base_color="$2"
          shift
        fi
        ;;
      --bot-padding) bot_padding=true ;;
      --box-color | --box-color=*)
        if [[ "$1" =~ ^--box-color= ]]; then
          box_color="${1#--box-color=}"
        elif [[ -z "${2:-}" ]]; then
          # stdoutがttyに接続されていない場合、escライブラリの
          # 色変数が空になる場合がある。
          shift
        elif [[ "$2" =~ ^-+ ]]; then
          log::error "$1: expected a ansi color code. perhaps try --box-color=\"$2\"?"
          return 1
        else
          box_color="$2"
          shift
        fi
        ;;
      --logo)
        if [[ -z "${MSG_LOGO:-}" ]]; then
          log::error 'MSG_LOGO is not set'
          return 1
        fi
        mid_padding=true
        while IFS= read -r line; do
          logo_lines+=( "$line" )
        done <<< "$MSG_LOGO"
        ;;
      --prompt | --prompt=*)
        if [[ "$1" =~ ^--prompt= ]]; then
          prompt="${1#--prompt=}"
        elif [[ -z "${2:-}" ]]; then
          log::error "$1: expected a string argument"
          return 1
        elif [[ "$2" =~ ^-+ ]]; then
          log::error "$1: expected a string argument. perhaps try --prompt=\"$2\"?"
          return 1
        else
          prompt="$2"
          shift
        fi
        ;;
      --fix-width) box_width="$MSG_BOX_WIDTH" ;;
      --full-width) width_fit_mode=full ;;
      --width | --width=*)
        if [[ "$1" =~ ^--width= ]]; then
          box_width="${1#--width=}"
        elif [[ -z "${2:-}" ]]; then
          log::error 'expected a numeric width value'
          return 1
        elif [[ ! "$2" =~ ^[0-9]+$ ]]; then
          log::error "$1: expected a numeric width value: $2"
          return 1
        else
          box_width="$2"
          shift
        fi
        ;;
      --top-padding) top_padding=true ;;
      -*) log::error "invalid option: $1"; return 1 ;;
      *) break ;;
    esac
    shift
  done

  : "${base_color:="$MSG_C_BASE"}"
  : "${box_color:="$MSG_C_HIGHLIGHT1"}"
  : "${prompt:=*}"

  opts_prompt=( --prompt "$prompt" )

  for line in "$@"; do
    messages+=( "$line" )
  done

  # 表示幅の計算
  # msg() に渡す文字列には `<hl></hl>` やエスケープシーケンスなどの
  # 表示時の文字数に反映されない文字が含まれることがあるため、--plain で
  # 装飾なしの実際に表示される文字列を取得して、表示幅を計算する

  for line in "${logo_lines[@]}"; do
    plain_text="$(MSG_INDENT=0 msg --no-prompt --plain --strip "$line")"
    len="${#plain_text}"
    (( len > max )) && max="$len"
  done

  for line in "${messages[@]}"; do
    plain_text="$(msg "${opts_prompt[@]}" --plain --strip "$line")"
    len="${#plain_text}"
    (( len > max )) && max="$len"
  done

  if [[ -n "${box_width:-}" ]]; then
    max="$box_width"
  elif [[ "$width_fit_mode" == 'full' ]]; then
    term_width="$(tput cols)"
    max=$(( $(tput cols) - padding * 2 - 2 ))
  fi

  # boxの上面と底面を作成
  local inner_width="$(( max + padding * 2 ))"
  local top='┌' mid='│' bot='└'
  local i
  for ((i=0; i<inner_width; i++)); do
    top+='─'
    bot+='─'
  done
  top+='┐'
  bot+='┘'

  msg::_box_line_padding() {
    printf '%b│%*s%*s%*s│\n' "$box_color" \
      "$padding" "" \
      "$max" "" \
      "$padding" ""
  }

  # 上面出力
  printf '%b%s%b\n' "$box_color" "$top" "$ESC_RESET"

  [[ "$top_padding" == 'true' ]] && msg::_box_line_padding

  # logo出力
  for line in "${logo_lines[@]}"; do
    plain_text="$(MSG_INDENT=0 msg --no-prompt --plain --strip "$line")"
    printf '%b│%*s' "$box_color" "$padding" ""
    MSG_INDENT=0 msg -b -n --no-prompt -c "$base_color" "$line"
    printf '%*s' $(( max - ${#plain_text} )) ""
    printf '%*s%b│\n' "$padding" "" "$box_color"
  done

  [[ "$mid_padding" == 'true' ]] && msg::_box_line_padding

  # 本文出力
  for line in "${messages[@]}"; do
    plain_text="$(msg "${opts_prompt[@]}" --plain --strip "$line")"
    printf '%b│%*s' "$box_color" "$padding" ""
    msg -n "${opts_prompt[@]}" -c "$base_color" "$line"
    printf '%*s' $(( max - ${#plain_text} )) ""
    printf '%*s%b│\n' "$padding" "" "$box_color"
  done

  [[ "$bot_padding" == 'true' ]] && msg::_box_line_padding

  # 底面出力
  printf '%b%s%b\n' "$box_color" "$bot" "$ESC_RESET"
}

msg::confirm() {
  local input
  if [[ "$1" == '-r' ]]; then
    shift
    msg -B --prompt-color "$ESC_C_WARNING" --prompt='!' -- \
      'press <b><hl>RETURN/ENTER</hl></b> to continue or press any other key to abort.' \
      </dev/tty >/dev/tty

    # stdin flush
    read -sr -t 0.1 -N 255 _
    read -sr -n 1 -p 'ready?' input </dev/tty >/dev/tty && echo
    if [[ -z "${input:-}" ]]; then
      return 0
    else
      return 1
    fi
  else
    msg -n -B --prompt-color "$ESC_C_WARNING" --prompt='!' -- "$* [y/N] "
    # stdin flush
    read -sr -t 0.1 -N 255 _
    IFS='' read -r input
    if [[ "$input" =~ ^([Yy]|[Yy][Ee][Ss])$ ]]; then
      return 0
    else
      return 1
    fi
  fi
}

msg::marker() {
  local base_color prompt
  case "${1:-option not set}" in
    --complete)
      base_color="$ESC_C_COMPLETE"
      prompt='✨️'
      shift
      ;;
    --warning)
      base_color="$ESC_C_WARNING"
      prompt='⚡'
      shift
      ;;
    --terminate)
      base_color="$ESC_C_CRITICAL"
      prompt='⛔'
      shift
      ;;
    -*) abort "invalid option: $1" ;;
    *) abort 'option required' ;;
  esac
  msg -b --base-color="$base_color" --prompt="$prompt" -- "$*"
  newline
}

msg::notice() {
  local color event
  case "$1" in
    --delete) event='DELETE'; color="$ESC_C_DANGER";  shift ;;
    --ignore) event='IGNORE'; color="$ESC_C_GRAYOUT"; shift ;;
    --link)   event='LINK';   color="$ESC_C_SUCCESS"; shift ;;
    --mkdir)  event='MKDIR';  color="$ESC_C_SUCCESS"; shift ;;
    --remove) event='REMOVE'; color="$ESC_C_DANGER";  shift ;;
    --rmdir)  event='RMDIR';  color="$ESC_C_DANGER";  shift ;;
    --skip)   event='SKIP';   color="$ESC_C_NOTICE";  shift ;;
    --unlink) event='UNLINK'; color="$ESC_C_DANGER";  shift ;;
    -*) abort "invalid option: $1" ;;
    *) abort 'option required' ;;
  esac
  msg --prompt "${ESC_DEFAULT}[ ${ESC_ATTR_BOLD}${color}${event}${ESC_RESET} ]" \
      --base-color "$ESC_DEFAULT" \
      -- "$*"
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
          log::error "$1: expected a string argument"
          return 1
        elif [[ "$2" =~ ^-+ ]]; then
          log::error "$1: expected a string argument. perhaps try --msg=\"$2\"?"
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
          log::error "$1: expected a string argument"
          return 1
        elif [[ "$2" =~ ^-+ ]]; then
          log::error "$1: expected a string argument. perhaps try --ok=\"$2\"?"
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
          log::error "$1: expected a string argument"
          return 1
        elif [[ "$2" =~ ^-+ ]]; then
          log::error "$1: expected a string argument. perhaps try --ng=\"$2\"?"
          return 1
        else
          result_ng="$2"
          shift
        fi
        ;;
      -*)
        log::error "invalid option: $1"
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
    "") log::error "command not found: ${cmd}"; return 1 ;;
    *)  log::error "disallowd command type \"${kind}\": ${cmd}"; return 1 ;;
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
    if [[ -s "$_MSG_EXEC_TMPFILE_STDERR" ]]; then
      printf '%s\n' "$(cat "$_MSG_EXEC_TMPFILE_STDERR")" >&2
    fi
  fi

  return "$rc"
}

msg::line() {
  local -r length="${1:-80}"
  local -r symbol='.'
  local line

  msg::_check_tty_mode

  if [[ "$MSG_TTY_MODE" == 'true' ]]; then
    for i in $(seq "$length"); do
      line="$(printf "${symbol}%.0s" $(seq 1 "$i"))"
      printf "\r%s" "${MSG_C_HIGHLIGHT1}${line}${ESC_RESET}"
      sleep 0.002
    done
  else
    line="$(printf "${symbol}%.0s" $(seq 1 "$length"))"
    printf "%s" "$line"
  fi
  echo
}
