# shellcheck shell=bash

LIB_VERSION='1.0.0';
LIB_DEPS=( trap log theme )
LIB_REQUIRES_BASH='>=4.1'
[[ "${1:-}" = '__IMPORT__' ]] && return 0;

: "${MSG_PROMPT:=>}"
: "${MSG_INDENT:=0}"
: "${MSG_DELAY:=0.1}"
: "${MSG_RENDERER_DEBUG:=0}"
: "${MSG_TOKENIZER_DEBUG:=0}"

msg::init() {
  (( ${MSG_INITIALIZED:-0} )) && return 0

  declare -gi _MSG_PYTHON3_UNAVAILABLE=0
  if ! python3 --version >/dev/null 2>&1; then
    core::warn 'python3 is not available. falling back to simplified mode.'
  fi

  declare -g _MSG_EXEC_TMPFILE_STDOUT
  declare -g _MSG_EXEC_TMPFILE_STDERR
  _MSG_EXEC_TMPFILE_STDOUT="$(mktemp 'tmp.msg.stdout.XXXXXX')"
  _MSG_EXEC_TMPFILE_STDERR="$(mktemp 'tmp.msg.stdout.XXXXXX')"

  # shellcheck disable=SC2329
  msg::_cleanup() {
    rm -f -- "$_MSG_EXEC_TMPFILE_STDOUT"
    rm -f -- "$_MSG_EXEC_TMPFILE_STDERR"
  }

  trap::concat 'EXIT' 'msg::_cleanup'
  trap::concat 'TERM' 'msg::_cleanup'
  trap::concat 'INT'  'msg::_cleanup'
  trap::concat 'HUP'  'msg::_cleanup'

  declare -gi MSG_INITIALIZED=1
}

msg::_isinit() {
  if (( ${MSG_INITIALIZED:-0} )); then
    return 0
  else
    core::error 'not initialized.'
    return 1
  fi
}

newline() { printf '\n'; }

msg::_tokenizer_debug() {
  local func
  read -r _ func _ < <(caller 0)
  (( MSG_TOKENIZER_DEBUG )) && logger --debug "[MSG TOKENIZER] ${func}: $*"
  return 0
}

msg::_tokenizer_init() {
  declare -ga _MSG_TOKENIZER_OUTPUT_TYPE=()
  declare -ga _MSG_TOKENIZER_OUTPUT_VALUE=()
  declare -gi _MSG_TOKENIZER_INITIALIZED=1
  msg::_tokenizer_debug 'MSG TOKENIZER INITIALIZED!'
}

msg::_tokenizer_isinit() {
  if (( ${_MSG_TOKENIZER_INITIALIZED:-0} )); then
    return 0
  else
    logger --error -v 'tokenizer is not initialized.'
    return 1
  fi
}

msg::_tokenizer_peek_type() {
  msg::_tokenizer_isinit || return 1

  local last_idx

  last_idx=$(( ${#_MSG_TOKENIZER_OUTPUT_TYPE[@]} - 1 ))
  if (( last_idx >= 0 )); then
    printf '%s' "${_MSG_TOKENIZER_OUTPUT_TYPE[last_idx]}"
  else
    printf ''
  fi
}

msg::_tokenizer_drop() {
  msg::_tokenizer_isinit || return 1

  local last_idx type value

  last_idx=$(( ${#_MSG_TOKENIZER_OUTPUT_TYPE[@]} - 1 ))
  if (( last_idx >= 0 )); then
    type="${_MSG_TOKENIZER_OUTPUT_TYPE[last_idx]}"
    value="${_MSG_TOKENIZER_OUTPUT_VALUE[last_idx]}"

    msg::_tokenizer_debug "drop from output token stack: ${type} ${value}"

    unset '_MSG_TOKENIZER_OUTPUT_TYPE[last_idx]'
    unset '_MSG_TOKENIZER_OUTPUT_VALUE[last_idx]'
    _MSG_TOKENIZER_OUTPUT_TYPE=( "${_MSG_TOKENIZER_OUTPUT_TYPE[@]}" )
    _MSG_TOKENIZER_OUTPUT_VALUE=( "${_MSG_TOKENIZER_OUTPUT_VALUE[@]}" )
  fi
}

msg::_tokenizer_push() {
  msg::_tokenizer_isinit || return 1
  (( $# != 2 )) && { logger --error -v 'invalid token'; return 1; }

  local type="$1"
  local value="$2"

  msg::_tokenizer_debug "push to output token stack: ${type} ${value}"

  _MSG_TOKENIZER_OUTPUT_TYPE+=( "$type" )
  _MSG_TOKENIZER_OUTPUT_VALUE+=( "$value" )
}

msg::_tokenize() {
  msg::_tokenizer_isinit || return 1

  local raw="$1"
  local -a lines=()
  local line i next text tag top

  while IFS= read -r line; do
    lines+=( "$line" )
  done <<<"$raw"

  if (( _MSG_RENDERER_CONTEXT['raw'] )); then
    msg::_tokenizer_push 'BEGIN' '_'
    msg::_tokenizer_push 'TEXT' "$raw"
    msg::_tokenizer_push 'NEWLINE' '_'
    msg::_tokenizer_push 'END' '_'
    return 0
  fi

  msg::_tokenizer_push 'BEGIN' '_'

  for i in "${!lines[@]}"; do
    line="${lines[i]}"

    msg::_tokenizer_debug "input line: ${line}"

    local next="$line"
    local restore_newline=0

    # ブロックタグのトークナイズ
    # タグのみの行をブロックタグ行として解釈
    # <@tag1><@tag2>...
    if [[ "$next" =~ ^(</?@[a-zA-Z0-9_-]+>)+$ ]]; then
      while [[ "$next" =~ ^(</?@[a-zA-Z0-9_-]+>)(.*)$ ]]; do
        tag=${BASH_REMATCH[1]}
        next=${BASH_REMATCH[2]}

        msg::_tokenizer_debug "block tag: ${tag}"
        msg::_tokenizer_debug "block next tag: ${next:-none}"

        case "$tag" in
          '<@'*)
            case "$tag" in
              '<@noprompt>') msg::_tokenizer_push 'BLOCK_OPEN' 'noprompt' ;;
              '<@b>') msg::_tokenizer_push 'BLOCK_OPEN' 'b' ;;
              '<@hl>') msg::_tokenizer_push 'BLOCK_OPEN' 'hl' ;;
              *)
                logger --error -v "invalid block tag: ${tag}"
                return 1
              ;;
            esac
            ;;
          '</@'*)
            top="$(msg::_tokenizer_peek_type)"
            if [[ "$top" == 'NEWLINE' ]]; then
              restore_newline=1
              msg::_tokenizer_drop
            fi

            case "$tag" in
              '</@noprompt>') msg::_tokenizer_push 'BLOCK_CLOSE' 'noprompt' ;;
              '</@b>') msg::_tokenizer_push 'BLOCK_CLOSE' 'b' ;;
              '</@hl>') msg::_tokenizer_push 'BLOCK_CLOSE' 'hl' ;;
              *)
                logger --error -v "invalid block tag: ${tag}"
                return 1
                ;;
            esac

            (( restore_newline )) && msg::_tokenizer_push 'NEWLINE' '_'
            ;;
        esac
      done

      continue
    fi

    # 通常行のトークナイズ
    msg::_tokenizer_push 'BEGIN_LINE' '_'

    while [[ "$line" =~ ^([^<]*)(</?@?[a-zA-Z0-9_-]+>)(.*)$ ]]; do
      text=${BASH_REMATCH[1]}
      tag=${BASH_REMATCH[2]}
      line=${BASH_REMATCH[3]}

      msg::_tokenizer_debug "text: ${text:-none}"
      msg::_tokenizer_debug "tag: ${tag:-none}"
      msg::_tokenizer_debug "next: ${line:-none}"

      # エスケープ '\\' -> '\', '\<' -> '<'
      if [[ "$text" =~ \\\\$ ]]; then
        text="${text%\\}"
      elif [[ "$text" =~ \\$ ]]; then
        text="${text%\\}"

        [[ -n "$text" ]] && msg::_tokenizer_push 'TEXT' "$text"
        msg::_tokenizer_push 'TEXT' "$tag"

        continue
      fi

      [[ -n "$text" ]] && msg::_tokenizer_push 'TEXT' "$text"

      case "$tag" in
        '<b>')  msg::_tokenizer_push 'TAG_OPEN'  'b' ;;
        '</b>') msg::_tokenizer_push 'TAG_CLOSE' 'b' ;;
        '<hl>')  msg::_tokenizer_push  'TAG_OPEN' 'hl' ;;
        '</hl>') msg::_tokenizer_push 'TAG_CLOSE' 'hl' ;;
        *) msg::_tokenizer_push 'TEXT' "$tag" ;;
      esac
    done

    [[ -n "$line" ]] && msg::_tokenizer_push 'TEXT' "$line"

    msg::_tokenizer_push 'END_LINE' '_'
    msg::_tokenizer_push 'NEWLINE' '_'
  done

  msg::_tokenizer_push 'END' '_'

  return 0
}

msg::_renderer_debug() {
  local func
  read -r _ func _ < <(caller 0)
  (( MSG_RENDERER_DEBUG )) && logger --debug "[MSG RENDERER] ${func}: $*"
  return 0
}

msg::_renderer_init() {
  declare -ga _MSG_RENDERER_STYLE_TAG_STACK=()
  declare -gA _MSG_RENDERER_CONTEXT=(
    ['indent_width']="$MSG_INDENT"
    ['prompt']="$MSG_PROMPT"
    ['plain']=0
    ['plain_prompt']=0
    ['raw']=0
    ['bold']=0
    ['base_style']='normal'
    ['highlight_style']='highlight'
    ['newline']=1
  )
  declare -ga _MSG_TOKENIZER_OUTPUT_TYPE=()
  declare -ga _MSG_TOKENIZER_OUTPUT_VALUE=()
  declare -g _MSG_RENDER_OUTPUT=
  declare -gi _MSG_RENDERER_INITIALIZED=1
  msg::_renderer_debug 'MSG RENDERER INITIALIZED!'
}

msg::_renderer_isinit() {
  if (( ${_MSG_RENDERER_INITIALIZED:-0} )); then
    return 0
  else
    logger --error -v 'renderer is not initialized.'
    return 1
  fi
}

msg::_render_indent() {
  msg::_renderer_isinit || return 1

  local indent
  local width="${_MSG_RENDERER_CONTEXT['indent_width']}"

  msg::_renderer_debug "rendering indent: width=${width}"

  indent="$(printf '%*s' "$width" '')"
  _MSG_RENDER_OUTPUT+="$indent"
}

msg::_render_prompt() {
  msg::_renderer_isinit || return 1
  [[ -z "${_MSG_RENDERER_CONTEXT['prompt']}" ]] && return 0

  local char="${_MSG_RENDERER_CONTEXT['prompt']}"
  msg::_renderer_debug "rendering prompt: char=${char}"

  (( _MSG_RENDERER_CONTEXT['plain_prompt'] )) || _MSG_RENDER_OUTPUT+="${STYLE_STDOUT['prompt']:-}"
  _MSG_RENDER_OUTPUT+="${char} "
  (( _MSG_RENDERER_CONTEXT['plain_prompt'] )) || _MSG_RENDER_OUTPUT+="${STYLE_STDOUT['rst']:-}"
}

msg::_render_tag() {
  msg::_renderer_isinit || return 1
  (( $# != 1 )) && { logger --error -v 'invalid options'; return 1; }

  local tag="$1"
  local highlight_style="${_MSG_RENDERER_CONTEXT['highlight_style']}"

  case "$tag" in
    b)  _MSG_RENDER_OUTPUT+="${STYLE_STDOUT['bold']:-}" ;;
    hl) _MSG_RENDER_OUTPUT+="${STYLE_STDOUT[${highlight_style}]:-}" ;;
  esac
}

msg::_render_style() {
  msg::_renderer_isinit || return 1
  (( _MSG_RENDERER_CONTEXT['plain'] )) && return 0

  local base_style="${_MSG_RENDERER_CONTEXT['base_style']}"
  local frame

  _MSG_RENDER_OUTPUT+="${STYLE_STDOUT['rst']:-}"
  _MSG_RENDER_OUTPUT+="${STYLE_STDOUT[${base_style}]}"
  (( _MSG_RENDERER_CONTEXT['bold'] )) && _MSG_RENDER_OUTPUT+="${STYLE_STDOUT['bold']:-}"

  # tag_stackを遡ってstyleを再描写
  for frame in "${_MSG_RENDERER_STYLE_TAG_STACK[@]}"; do
    msg::_render_tag "$frame"
  done
}

msg::_push_style_tag_stack() {
  msg::_renderer_isinit || return 1
  (( $# != 1 )) && { logger --error -v 'invalid tag'; return 1; }

  local tag="$1"
  msg::_renderer_debug "push to tag_stack: ${tag}"
  _MSG_RENDERER_STYLE_TAG_STACK+=( "$tag" )
}

msg::_pop_style_tag_stack() {
  msg::_renderer_isinit || return 1
  (( $# != 1 )) && { logger --error -v 'invalid tag'; return 1; }
  (( ${#_MSG_RENDERER_STYLE_TAG_STACK[@]} == 0 )) && return 0

  local tag="$1"
  local i

  msg::_renderer_debug "pop from tag_stack: ${tag}"

  for (( i = ${#_MSG_RENDERER_STYLE_TAG_STACK[@]} - 1; i >= 0; i-- )); do
    if [[ "${_MSG_RENDERER_STYLE_TAG_STACK[i]}" == "$tag" ]]; then
      unset '_MSG_RENDERER_STYLE_TAG_STACK[i]'
      _MSG_RENDERER_STYLE_TAG_STACK=( "${_MSG_RENDERER_STYLE_TAG_STACK[@]}" )
      return 0
    fi
  done

  return 1
}

msg::_render_tag_open() {
  msg::_renderer_isinit || return 1
  (( $# != 1 )) && { logger --error -v 'invalid options'; return 1; }
  (( _MSG_RENDERER_CONTEXT['plain'] )) && return 0

  local tag="$1"

  msg::_push_style_tag_stack "$tag"
  msg::_renderer_debug "$(declare -p '_MSG_RENDERER_STYLE_TAG_STACK')"

  msg::_render_tag "$tag"
}

msg::_render_tag_close() {
  msg::_renderer_isinit || return 1
  (( $# != 1 )) && { logger --error -v 'invalid options'; return 1; }
  (( _MSG_RENDERER_CONTEXT['plain'] )) && return 0

  local tag="$1"

  msg::_pop_style_tag_stack "$tag"
  msg::_renderer_debug "$(declare -p '_MSG_RENDERER_STYLE_TAG_STACK')"
  msg::_render_style
}

msg::_render_token() {
  msg::_renderer_isinit || return 1
  msg::_tokenizer_isinit || return 1

  local i type value

  for i in "${!_MSG_TOKENIZER_OUTPUT_TYPE[@]}"; do
    type="${_MSG_TOKENIZER_OUTPUT_TYPE[i]}"
    value="${_MSG_TOKENIZER_OUTPUT_VALUE[i]}"

    msg::_renderer_debug "rendering token[${i}]: ${type} ${value}"

    case "$type" in
      BEGIN)
        ;;
      BEGIN_LINE)
        msg::_render_indent
        msg::_render_prompt
        msg::_render_style
        ;;
      TEXT)
        _MSG_RENDER_OUTPUT+="$value"
        ;;
      TAG_OPEN)
        msg::_render_tag_open "$value"
        ;;
      TAG_CLOSE)
        msg::_render_tag_close "$value"
        ;;
      BLOCK_OPEN)
        case "$value" in
          noprompt)
            _MSG_RENDERER_CONTEXT['prompt']=
            ;;
          b|hl)
            msg::_push_style_tag_stack "$value"
            ;;
          *)
            logger --error -v "invalid value: ${value}"
            return 1
            ;;
        esac
        ;;
      BLOCK_CLOSE)
        case "$value" in
          noprompt)
            _MSG_RENDERER_CONTEXT['prompt']='>'
            ;;
          b|hl)
            msg::_pop_style_tag_stack "$value"
            ;;
          *)
            logger --error -v "invalid value: ${value}"
            return 1
            ;;
        esac
        ;;
      END_LINE)
        if (( ! _MSG_RENDERER_CONTEXT['plain'] )); then
          _MSG_RENDER_OUTPUT+="${STYLE_STDOUT['rst']:-}"
        fi
        ;;
      NEWLINE)
        _MSG_RENDER_OUTPUT+=$'\n'
        ;;
      END)
        ;;
      *)
        logger --error "invaid token type: ${type}"
        return 1
        ;;
    esac
  done

  return 0
}

msg::_render() {
  msg::_renderer_isinit || return 1

  local raw="$*"
  local i type value

  msg::_renderer_debug "↓↓ input raw ↓↓
${raw}"
  msg::_renderer_debug "↑↑ input raw ↑↑"
  msg::_renderer_debug "$(declare -p '_MSG_RENDERER_CONTEXT')"

  msg::_tokenizer_init
  msg::_tokenize "$raw"
  msg::_render_token

  # 末尾の改行を除去
  if (( ! _MSG_RENDERER_CONTEXT['newline'] )); then
    _MSG_RENDER_OUTPUT="${_MSG_RENDER_OUTPUT%$'\n'}"
  fi

  # render output
  msg::_renderer_debug "↓↓ rendering result ↓↓
$(printf '%q' "$_MSG_RENDER_OUTPUT")"
  msg::_renderer_debug "↑↑ rendering result ↑↑"
  printf '%b' "$_MSG_RENDER_OUTPUT"

  return 0
}

msg() {
  # スクリプトのメッセージ出力に利用できます。
  # 引数にとった文字列をオプションに基づいて整形・色付けして出力します。
  # themeライブラリの `STYLE_STDOUT` を利用して標準出力に出力します。
  #
  # Environment Variables:
  #
  #   MSG_INDENT
  #        インデントの幅を数値で指定します(0でインデントなし)。
  #
  #   MSG_DELAY
  #        メッセージ出力後のsleepの秒数。
  #        標準出力がターミナルに接続していない場合は、`MSG_DELAY=0` で実行されます。
  #
  # Tags:
  #
  #   引数に取る文字列は以下のタグを解釈します。
  #     <hl>...</hl>: 囲まれた範囲の文字をハイライトする。
  #     <b>...</b>: 囲まれた範囲の文字を太字にする。
  #
  # Options:
  #   -b, --bold
  #
  #        メッセージ本文を太字で出力します。
  #
  #   -n   末尾で改行しません。
  #
  #   -p, --plain
  #
  #        styleの適用なし、タグ解釈なし、タグ文字非表示で出力します。
  #        `-r` オプションが指定された場合は、そちらが優先されます。
  #        ( `-ppp` オプションが指定された場合は、`-p, `-pp` が同時に適用されます。)
  #
  #   -pp, --plain-prompt
  #
  #        styleの適用なし、でプロンプトを出力します。
  #        `-r` オプションが指定された場合は、そちらが優先されます。
  #        ( `-ppp` オプションが指定された場合は、`-p, `-pp` が同時に適用されます。)
  #
  #   -r, --raw
  #
  #        引数にとった文字列をそのまま出力します。
  #
  #   -s, --base-style <style>
  #
  #        <style> 名を出力スタイルのデフォルトに設定します。
  #        このスタイルは、スタイルを操作する他のオプションにオーバーライドされます。
  #
  #   -H, --highlight-style <style>
  #
  #        <style> 名を出力スタイルのデフォルトに設定します。
  #        このスタイルは、スタイルを操作する他のオプションにオーバーライドされます。
  #
  #   --prompt <prompt string>
  #
  #        プロンプト文字列を指定します。
  #        指定されない場合は、環境変数 `MSG_PROMPT` で指定された文字列を利用します。
  #
  #   --no-prompt
  #
  #        プロンプトなしで出力します。

  msg::_renderer_init

  while (( $# > 0 )); do
    case "$1" in
      --)
        shift
        break
        ;;
      -b | --bold) _MSG_RENDERER_CONTEXT['bold']=1 ;;
      -n) _MSG_RENDERER_CONTEXT['newline']=0 ;;
      -p | --plain) _MSG_RENDERER_CONTEXT['plain']=1 ;;
      -pp | --plain-prompt) _MSG_RENDERER_CONTEXT['plain_prompt']=1 ;;
      -ppp)
        _MSG_RENDERER_CONTEXT['plain']=1
        _MSG_RENDERER_CONTEXT['plain_prompt']=1
        ;;
      -r | --raw) _MSG_RENDERER_CONTEXT['raw']=1 ;;
      -s | --base-style | --base-style=*)
        if [[ "$1" =~ ^--base-style= ]]; then
          _MSG_RENDERER_CONTEXT['base_style']="${1#--base-style=}"
        elif [[ -z "${2:-}" ]]; then
          logger --error 'missing style name'
          return 1
        else
          _MSG_RENDERER_CONTEXT['base_style']="$2"
          shift
        fi
        ;;
      -H | --highlight-style | --highlight-style=*)
        if [[ "$1" =~ ^--highlight-style= ]]; then
          _MSG_RENDERER_CONTEXT['highlight_style']="${1#--highlight-style=}"
        elif [[ -z "${2:-}" ]]; then
          logger --error 'missing style name'
          return 1
        else
          _MSG_RENDERER_CONTEXT['highlight_style']="$2"
          shift
        fi
        ;;
      --prompt | --prompt=*)
        if [[ "$1" =~ ^--prompt= ]]; then
          _MSG_RENDERER_CONTEXT['prompt']="${1#--prompt=}"
        elif [[ -z "${2:-}" ]]; then
          logger --error 'missing prompt symbol'
          return 1
        else
          _MSG_RENDERER_CONTEXT['prompt']="$2"
          shift
        fi
        ;;
      --no-prompt) _MSG_RENDERER_CONTEXT['prompt']= ;;
      -*) logger --error -v "invalid option: $1"; return 1 ;;
      *) break ;;
    esac
    shift
  done

  msg::_render "${*:-}"

  [[ -t 1 ]] && sleep "$MSG_DELAY"

  return 0
}

msg::_repeat_char() {
  local char="$1"
  local count="$2"
  local output

  (( count < 0 )) && count=0

  printf -v output '%*s' "$count" ''
  printf '%s' "${output// /${char}}"
}

msg::_calc_width() {
  # 表示幅の計算
  # msg() に渡す文字列には `<hl></hl>` やエスケープシーケンスなどの
  # 表示時の文字数に反映されない文字が含まれることがあるため、--plain で
  # 装飾なしの実際に表示される文字列を取得して、表示幅を計算する。
  # pythonが利用できる場合、unicodedataから表示幅を計算する。

  python3 - "$1" <<'PYTHON'
import os
import sys

dotfiles_path = os.environ.get('DOTFILES_PATH')
if dotfiles_path is None:
  raise RuntimeError('DOTFILES_PATH is not set')

sys.path.insert(0, os.path.join(dotfiles_path, 'lib/python/_vendor'))

from wcwidth import wcswidth

if len(sys.argv) != 2:
  raise RuntimeError("usage: msg::_calc_width <string>")

s = sys.argv[1]
max_width = 0

for line in s.splitlines():
  w = wcswidth(line)

  if w < 0:
    escaped = line.encode("unicode_escape").decode()
    raise RuntimeError(f"string contains non-printable characters: {escaped}")

  if w > max_width:
    max_width = w

print(max_width)
PYTHON
}

msg::box() {
  # usage: msg::box [box options] [msg options] -- <message>...

  msg::_isinit || return 1

  local box_style='box'
  local box_padding_top=1
  local box_padding_bottom=1
  local box_padding_left=1
  local box_padding_right=1
  local -a msg_args=()

  while (( $# > 0 )); do
    case "$1" in
      --) shift; break ;;
      --box-style | --box-style=*)
        if [[ "$1" =~ ^--box-style= ]]; then
          box_style="${1#--box-style=}"
        elif [[ -z "${2:-}" ]]; then
          logger --error -v "$1: missing box style"
          return 1
        else
          box_style="$2"
          shift
        fi
        ;;
      --box-padding-top | --box-padding-top=*)
        if [[ "$1" =~ ^--box-padding-top= ]]; then
          box_padding_top="${1#--box-padding-top=}"
        elif [[ -z "${2:-}" ]]; then
          logger --error -v "$1: missing padding top"
          return 1
        else
          box_padding_top="$2"
          shift
        fi
        ;;
      --box-padding-bottom | --box-padding-bottom=*)
        if [[ "$1" =~ ^--box-padding-bottom= ]]; then
          box_padding_bottom="${1#--box-padding-bottom=}"
        elif [[ -z "${2:-}" ]]; then
          logger --error -v "$1: missing padding bottom"
          return 1
        else
          box_padding_bottom="$2"
          shift
        fi
        ;;
      --box-padding-left | --box-padding-left=*)
        if [[ "$1" =~ ^--box-padding-left= ]]; then
          box_padding_left="${1#--box-padding-left=}"
        elif [[ -z "${2:-}" ]]; then
          logger --error -v "$1: missing padding left"
          return 1
        else
          box_padding_left="$2"
          shift
        fi
        ;;
      --box-padding-right | --box-padding-right=*)
        if [[ "$1" =~ ^--box-padding-right= ]]; then
          box_padding_right="${1#--box-padding-right=}"
        elif [[ -z "${2:-}" ]]; then
          logger --error -v "$1: missing padding right"
          return 1
        else
          box_padding_right="$2"
          shift
        fi
        ;;
      -*) msg_args+=( "$1" ) ;;
      *) break ;;
    esac
    shift
  done

  if \
    [[
      ! "$box_padding_top" =~ ^[0-9]+$ ||
      ! "$box_padding_bottom" =~ ^[0-9]+$ ||
      ! "$box_padding_left" =~ ^[0-9]+$ ||
      ! "$box_padding_right" =~ ^[0-9]+$
    ]]
  then
    logger --error -v 'invalid padding width option. expected numeric value.'
    return 1
  fi

  # fallback
  # python3が利用できない場合、msg()にそのまま渡す
  if (( _MSG_PYTHON3_UNAVAILABLE )); then
    for msg in "$@"; do
      msg "${msg_args[@]}" -- "$msg"
    done
    return 0
  fi

  local -a inner_rendered_lines=()
  local -a inner_line_widths=()
  local max_width=0
  local str i line
  local rendered rendered_plain width tmp rule pad

  for str in "$@"; do
    logger --debug 'rendering messages...'
    rendered="$(msg "${msg_args[@]}" -- "$str")"

    logger --debug 'rendering plain messages...'
    rendered_plain="$(msg -ppp "${msg_args[@]}" -- "$str")"

    while IFS= read -r line; do
      inner_rendered_lines+=( "$line" )
    done <<<"$rendered"

    while IFS= read -r line; do
      width="$(msg::_calc_width "$line")"
      inner_line_widths+=( "$width" )
      tmp="$(printf '%03d' "$width")"
      logger --debug "calculating line width ... ${tmp}: ${line}"
      (( width > max_width )) && max_width="$width"
    done <<<"$rendered_plain"
  done

  logger --debug "max width: ${max_width}"

  rule="$(msg::_repeat_char '─' "$(( max_width + box_padding_left + box_padding_right ))")"

  # top
  printf '%b┌%b┐\n' "${STYLE_STDOUT[${box_style}]:-}" "$rule"

  # padding top
  for (( i = 0; i < box_padding_top; i++ )); do
    printf '%b│%*s│\n' \
      "${STYLE_STDOUT[${box_style}]:-}" \
      "$(( max_width + box_padding_left + box_padding_right ))" ''
  done

  # body
  for i in "${!inner_rendered_lines[@]}"; do
    pad="$(( max_width - ${inner_line_widths[i]} ))"

    printf '│%*s%b%*s%*s%b│\n' \
      "$box_padding_left" '' \
      "${inner_rendered_lines[i]}" \
      "$pad" '' \
      "$box_padding_right" '' \
      "${STYLE_STDOUT[${box_style}]:-}"
  done

  # padding bottom
  for (( i = 0; i < box_padding_bottom; i++ )); do
    printf '│%*s│\n' "$(( max_width + box_padding_left + box_padding_right ))" ''
  done

  # bottom
  printf '└%b┘%b\n' "$rule" "${STYLE_STDOUT['rst']:-}"

  #[[ -t 1 ]] && sleep "$MSG_DELAY"

  return 0
}













#: "${MSG_C_BASE:="$ESC_C_BASE"}"
#: "${MSG_C_HIGHLIGHT1:="$ESC_C_MAIN"}"
##: "${MSG_C_HIGHLIGHT2:="$ESC_C_ACCENT1"}"
#: "${MSG_C_HIGHLIGHT2:="$ESC_CYAN"}"
#: "${MSG_LOGO:-}"
#: "${MSG_BOX_WIDTH:=80}"


#if [[ -t 1 ]]; then
#  : "${MSG_DELAY:=0.1}"
#else
#  MSG_DELAY=0
#fi

#if python3 --version >/dev/null 2>&1; then
#  MSG_PYTHON3_UNAVAILABLE=true
#  core::warning 'python3 is not available. falling back to simplified mode.'
#fi

#_MSG_EXEC_TMPFILE_STDOUT="$(mktemp)"
#_MSG_EXEC_TMPFILE_STDERR="$(mktemp)"

#msg::_cleanup() {
#  rm -f -- "$_MSG_EXEC_TMPFILE_STDOUT"
#  rm -f -- "$_MSG_EXEC_TMPFILE_STDERR"
#}
#
#trap::concat 'EXIT' 'msg::_cleanup'
#trap::concat 'TERM' 'msg::_cleanup'
#trap::concat 'INT'  'msg::_cleanup'
#trap::concat 'HUP'  'msg::_cleanup'

#msg::_check_tty_mode() {
#  if [[ -t 1 ]]; then
#    : "${MSG_TTY_MODE:=true}"
#  else
#    MSG_TTY_MODE=false
#  fi
#}


#msg() {
#  # スクリプトのメッセージ出力に利用できます。
#  # 引数にとった文字列をオプションに基づいて整形・色付けして出力します。
#  #
#  # env:
#  #   MSG_INDENT
#  #        インデントの高さを数値で指定します(0でインデントなし)。
#  #
#  # tags:
#  #   引数に取る文字列は以下のタグを解釈します。
#  #     <hl>...</hl>: 囲まれた範囲の文字をプロンプトと同様の色でハイライトする
#  #     <b>...</b>: 囲まれた範囲の文字を強調する
#  #
#  # options:
#  #   -2   ハイライトカラーを変更します。
#  #        セクションに応じて、使用します。
#  #
#  #   -b, --bold
#  #        メッセージ本文を太字で出力します。
#  #
#  #   -B, --prompt-bold
#  #        プロンプト文字を太字で出力します。
#  #
#  #   -c, --base-color <ansi color code>
#  #        ベースの文字列色をANSI color codeで指定します。
#  #        hlタグやプロンプト色には影響しません。
#  #
#  #   -C, --hl-color <ansi color code>
#  #        <hl>タグのハイライト文字列色をANSI color codeで指定します。
#  #
#  #   -h, --highlight <selector>
#  #        selectorに従い、強調表示を行います。
#  #
#  #        selector:
#  #          - complete
#  #          - warn
#  #          - note
#  #          - tip
#  #
#  #   -n   末尾で改行しません。
#  #
#  #   -p, --progress
#  #        末尾で処理中を示すプログレスドットを出力します。
#  #          > example...
#  #
#  #   -P, --plain
#  #        プロンプト非表示かつバックスラッシュを解釈せずに出力します。
#  #        タグの解釈も行いません。
#  #        --stripオプションが指定された場合は、制御文字およびタグ文字の除去を
#  #        行ったうえで出力されます。
#  #
#  #   -r   \rで出力行をリセット後にメッセージを出力する。
#  #
#  #   -s, --strip
#  #       制御文字(ANSI, ASCII)およびタグの除去をして出力します。
#  #
#  #   --spinner
#  #        --progressオプションを有効化し、スピナー行を出力します。
#  #        実行プロセスをkillするまで無限ループで出力し続けます。
#  #
#  #        使用例:
#  #          バックグラウンド等で実行し、任意の処理実行後にtrap等でkillする
#  #          msg::exec() などを参考にしてください。
#  #            $ msg -s &
#  #            ⠧ wait...
#  #
#  #   --ok, --ng, --result
#  #        指定の結果文字列をプログレスドットのあとに出力します。
#  #        オプションごとにカラーが異なります。
#  #        --ok: blue
#  #        --ng: red
#  #        --result: hlタグと同様のカラー
#  #
#  #          $ msg --result EXAMPLE -- "message"
#  #          > message...EXAMPLE
#  #
#  #   --prompt
#  #        プロンプトを指定します。
#  #        指定されない場合は、環境変数 MSG_PROMPT_CHAR で指定された文字列を利用します。
#  #          $ msg --prompt='#' -- message
#  #          # message
#  #
#  #   --prompt-color <ansi color code>
#  #        プロンプト文字列色をANSI color codeで指定します。
#  #
#  #   --no-prompt
#  #        プロンプトなしで出力します。
#
#  local prompt_bold prompt_str prompt_color
#  local prompt_indent='' no_prompt=false
#  local bold base_color hl_color
#  local result_str result_color
#  local hl_selector
#  local p
#
#  local -r dots='...'
#  #local -r spinner_dot='⠧⠏⠛⠹⠼⠶'
#  #local -r spinner_line='/-\|'
#  local -r spinner_star='-+*+-'
#  local spinner_chars="$spinner_star"
#  local spinner=false
#
#  local line_reset=false
#  local newline=true
#  local progress_dots=false
#  local strip=false
#  local style_plain=false
#
#  while (( $# > 0 )); do
#    case "$1" in
#      --) shift; break ;;
#      -2)
#        hl_color="$MSG_C_HIGHLIGHT2"
#        prompt_color="$MSG_C_HIGHLIGHT2"
#        ;;
#      -b | --bold) bold="${STD_STDOUT['sgr_bold']}" ;;
#      -B | --prompt-bold) prompt_bold="${STYLE_STDOUT['sgr_bold']}" ;;
#      -c | --base-color | --base-color=*)
#        if [[ "$1" =~ ^--base-color= ]]; then
#          base_color="${1#--base-color=}"
#        elif [[ -z "${2:-}" ]]; then
#          # stdoutがttyに接続されていない場合、escライブラリの
#          # 色変数が空になる場合がある。
#          shift
#        elif [[ "$2" =~ ^-+ ]]; then
#          logger --error "$1: expected a ansi color code. perhaps try --base-color=\"$2\"?"
#          return 1
#        else
#          base_color="$2"
#          shift
#        fi
#        ;;
#      -C | --hl-color | --hl-color=*)
#        if [[ "$1" =~ ^--hl-color= ]]; then
#          hl_color="${1#--hl-color=}"
#        elif [[ -z "${2:-}" ]]; then
#          # stdoutがttyに接続されていない場合、escライブラリの
#          # 色変数が空になる場合がある。
#          shift
#        elif [[ "$2" =~ ^-+ ]]; then
#          logger --error "$1: expected a ansi color code. perhaps try --hl-color=\"$2\"?"
#          return 1
#        else
#          hl_color="$2"
#          shift
#        fi
#        ;;
#      -h | --highlight | --highlight=*)
#        if [[ "$1" =~ ^--highlight= ]]; then
#          hl_selector="${1#--highlight=}"
#        elif [[ -z "${2:-}" ]]; then
#          logger --error "$1: expected string value"
#          return 1
#        elif [[ "$2" =~ ^-+ ]]; then
#          logger --error "$1: must be one of selector. perhaps try --highlight=\"$2\"?"
#          return 1
#        else
#          hl_selector="$2"
#          shift
#        fi
#        case "$hl_selector" in
#          complete)
#            base_color="$ESC_C_COMPLETE"
#            prompt_str='>>>'
#            #p="$(( RANDOM % 7 + 1 ))"
#            #case "$p" in
#            #  1) prompt_str='🛸' ;;
#            #  2) prompt_str='🛰️' ;;
#            #  3) prompt_str='🚀' ;;
#            #  4) prompt_str='🪐' ;;
#            #  5) prompt_str='👾' ;;
#            #  6) prompt_str='🌟' ;;
#            #  7) prompt_str='💫' ;;
#            #esac
#            ;;
#          warn)
#            base_color="$ESC_C_WARNING"
#            prompt_str='⚡️'
#            ;;
#          return)
#            base_color="$ESC_C_NOTICE"
#            #prompt_color="$ESC_C_NOTICE"
#            prompt_str='<'
#            ;;
#          tip)
#            base_color="$ESC_C_NOTICE"
#            prompt_color="$ESC_C_NOTICE"
#            prompt_str='🍪 tip:'
#            ;;
#          *)
#            log::error "must be one of 'warn'"
#            return 1
#            ;;
#        esac
#        ;;
#      -n) newline=false ;;
#      -p | --progress)
#        progress_dots=true
#        line_reset=true
#        ;;
#      -P | --plain) style_plain=true ;;
#      -r) line_reset=true ;;
#      -s | --strip) strip=true ;;
#      --spinner)
#        # 無限ループするので呼び出し側でkillが必要です
#        progress_dots=true
#        spinner=true
#        newline=false
#        ;;
#      --ok | --ok=*)
#        if [[ "$1" =~ ^--ok= ]]; then
#          result_str="${1#--ok=}"
#        elif [[ -z "${2:-}" ]]; then
#          logger --error "$1: expected a string argument"
#          return 1
#        elif [[ "$2" =~ ^-+ ]]; then
#          logger --error "$1: expected a string argument. perhaps try --ok=\"$2\"?"
#          return 1
#        else
#          result_str="$2"
#          shift
#        fi
#        result_color="${ESC_ATTR_BOLD}${ESC_C_SUCCESS}"
#        ;;
#      --ng | --ng=*)
#        if [[ "$1" =~ ^--ng= ]]; then
#          result_str="${1#--ng=}"
#        elif [[ -z "${2:-}" ]]; then
#          logger --error "$1: expected a string argument"
#          return 1
#        elif [[ "$2" =~ ^-+ ]]; then
#          logger --error "$1: expected a string argument. perhaps try --ng=\"$2\"?"
#          return 1
#        else
#          result_str="$2"
#          shift
#        fi
#        result_color="${ESC_ATTR_BOLD}${ESC_C_FAILURE}"
#        ;;
#      --result | --result=*)
#        if [[ "$1" =~ ^--result= ]]; then
#          result_str="${1#--result=}"
#        elif [[ -z "${2:-}" ]]; then
#          logger --error "$1: expected a string argument"
#          return 1
#        elif [[ "$2" =~ ^-+ ]]; then
#          logger --error "$1: expected a string argument. perhaps try --ok=\"$2\"?"
#          return 1
#        else
#          result_str="$2"
#          shift
#        fi
#        result_color="${ESC_ATTR_BOLD}${MSG_C_HIGHLIGHT1}"
#        ;;
#      --prompt | --prompt=*)
#        if [[ "$1" =~ ^--prompt= ]]; then
#          prompt_str="${1#--prompt=}"
#        elif [[ -z "${2:-}" ]]; then
#          logger --error "$1: expected a string argument"
#          return 1
#        elif [[ "$2" =~ ^-+ ]]; then
#          logger --error "$1: expected a string argument. perhaps try --prompt=\"$2\"?"
#          return 1
#        else
#          prompt_str="$2"
#          shift
#        fi
#        ;;
#      --prompt-color | --prompt-color=*)
#        if [[ "$1" =~ ^--prompt-color= ]]; then
#          prompt_color="${1#--prompt-color=}"
#        elif [[ -z "${2:-}" ]]; then
#          # stdoutがttyに接続されていない場合、escライブラリの
#          # 色変数が空になる場合がある。
#          shift
#        elif [[ "$2" =~ ^-+ ]]; then
#          logger --error "$1: expected a ansi color code. perhaps try --prompt-color=\"$2\"?"
#          return 1
#        else
#          prompt_color="$2"
#          shift
#        fi
#        ;;
#      --no-prompt) no_prompt=true ;;
#      -*) logger --error "invalid option: $1"; return 1 ;;
#      *) break ;;
#    esac
#    shift
#  done
#
#  prompt_bold="$ESC_ATTR_BOLD"
#
#  if [[ "$no_prompt" == 'true' ]]; then
#    unset prompt_str
#  else
#    : "${prompt_str:="$MSG_PROMPT_CHAR"}"
#  fi
#
#  : "${prompt_color:="$MSG_C_HIGHLIGHT1"}"
#  : "${hl_color:="$MSG_C_HIGHLIGHT1"}"
#  : "${base_color:="$MSG_C_BASE"}"
#
#  msg::_check_tty_mode
#
#  [[ $# -eq 0 ]] && { logger --error 'message string is required'; return 1; }
#
#  local msg prompt result
#  local s="$*"
#
#  prompt_indent="$(printf '%*s' "$MSG_INDENT" '')"
#
#  if [[ "$style_plain" == 'true' ]]; then
#    s="${s//<hl>/}"
#    s="${s//<\/hl>/}"
#    s="${s//<b>/}"
#    s="${s//<\/b>/}"
#    msg="$s"
#    prompt="${prompt_indent}${prompt_str:-}${prompt_str+ }"
#
#    if [[ "$strip" == 'true' ]]; then
#      printf '%s%s' "$prompt" "$msg" \
#        | sed -E 's/\x1b\[[0-9;?]*[ -/]*[@-~]//g' \
#        | tr -d '\000-\010\013\014\016-\037\177'
#    else
#      printf '%s%s' "$prompt" "$msg"
#    fi
#  elif [[ "$MSG_TTY_MODE" == 'true' ]]; then
#    s="${s//<hl>/${hl_color}}"
#    s="${s//<\/hl>/${base_color}}"
#    s="${s//<b>/${ESC_ATTR_BOLD}}"
#    s="${s//<\/b>/${ESC_ATTR_RESET_IE}}"
#    msg="${bold:-${ESC_ATTR_RESET_IE}}${base_color}${s}"
#    prompt="${prompt_bold:-${ESC_ATTR_RESET_IE}}${prompt_color}${prompt_indent}${prompt_str:-}${prompt_str+ }"
#    result="${result_color:-}${result_str:-}"
#
#    if [[ "$progress_dots" == 'true' ]]; then
#      for (( i=0; i<=${#dots}; i++ )); do
#        printf '\r\033[2K%s' "${prompt}${msg}${dots:0:i}${ESC_RESET}"
#        sleep 0.1
#      done
#    fi
#
#    if [[ "$spinner" == 'true' ]]; then
#      local prompt_spinner
#      local i=0
#      local n="${#spinner_chars}"
#      while true; do
#        prompt_spinner="${prompt_indent}${prompt_color}${spinner_chars:i:1} "
#        printf '\r\033[2K%s' "${prompt_spinner}${msg}${dots}${ESC_RESET}"
#        i=$(( (i + 1) % n ))
#        sleep 0.1
#      done
#    fi
#
#    [[ "$line_reset" == 'true' ]] && printf '\r\033[2K'
#    printf '%s' "${prompt}${msg}"
#    if [[ -z "$result" ]]; then
#      [[ "$progress_dots" == 'true' ]] && printf '%s' "$dots"
#    else
#      printf '%s' "${dots}${result}"
#    fi
#    printf '%s' "$ESC_RESET"
#  else
#    # stdout is not connected to a tty
#    s="${s//<hl>/}"
#    s="${s//<\/hl>/}"
#    s="${s//<b>/}"
#    s="${s//<\/b>/}"
#    msg="$s"
#    prompt="${prompt_indent}${prompt_str:-}${prompt_str+ }"
#    result="${result_str:-}"
#
#    if [[ -z "$result" ]]; then
#      printf '%s' "${prompt}${msg}"
#      [[ "$progress_dots" == 'true' ]] && printf '%s' "$dots"
#    else
#      printf '%s' "$result"
#    fi
#  fi
#
#  [[ "$newline" == 'true' ]] && printf '\n'
#  [[ "$MSG_TTY_MODE" == 'true' ]] && sleep "$MSG_DELAY"
#  return 0
#}















#msg::box() {
#  local term_width box_width
#  local box_color base_color base_color
#  local prompt
#  local line plain_text len max=0 max_logo=0
#  local -a messages=() logo_lines=() opts_prompt=()
#  local padding=2 top_padding=false mid_padding=false bot_padding=false
#  local width_fit_mode=auto
#
#  while (( $# > 0 )); do
#    case "$1" in
#      --) shift; break ;;
#      -c | --base-color | --base-color=*)
#        if [[ "$1" =~ ^--base-color= ]]; then
#          base_color="${1#--base-color=}"
#        elif [[ -z "${2:-}" ]]; then
#          # stdoutがttyに接続されていない場合など空になる場合がある。
#          shift
#        elif [[ "$2" =~ ^-+ ]]; then
#          log::error "$1: expected a ansi color code. perhaps try --base-color=\"$2\"?"
#          return 1
#        else
#          base_color="$2"
#          shift
#        fi
#        ;;
#      --bot-padding) bot_padding=true ;;
#      --box-color | --box-color=*)
#        if [[ "$1" =~ ^--box-color= ]]; then
#          box_color="${1#--box-color=}"
#        elif [[ -z "${2:-}" ]]; then
#          # stdoutがttyに接続されていない場合など空になる場合がある。
#          shift
#        elif [[ "$2" =~ ^-+ ]]; then
#          log::error "$1: expected a ansi color code. perhaps try --box-color=\"$2\"?"
#          return 1
#        else
#          box_color="$2"
#          shift
#        fi
#        ;;
#      --logo)
#        if [[ -z "${MSG_LOGO:-}" ]]; then
#          logger --error -v 'MSG_LOGO is not set'
#          return 1
#        fi
#        mid_padding=true
#        while IFS='' read -r line; do
#          logo_lines+=( "$line" )
#        done <<< "$MSG_LOGO"
#        ;;
#      --prompt | --prompt=*)
#        if [[ "$1" =~ ^--prompt= ]]; then
#          prompt="${1#--prompt=}"
#        elif [[ -z "${2:-}" ]]; then
#          log::error "$1: expected a string argument"
#          return 1
#        elif [[ "$2" =~ ^-+ ]]; then
#          log::error "$1: expected a string argument. perhaps try --prompt=\"$2\"?"
#          return 1
#        else
#          prompt="$2"
#          shift
#        fi
#        ;;
#      --fix-width) box_width="$MSG_BOX_WIDTH" ;;
#      --full-width) width_fit_mode=full ;;
#      --width | --width=*)
#        if [[ "$1" =~ ^--width= ]]; then
#          box_width="${1#--width=}"
#        elif [[ -z "${2:-}" ]]; then
#          log::error 'expected a numeric width value'
#          return 1
#        elif [[ ! "$2" =~ ^[0-9]+$ ]]; then
#          log::error "$1: expected a numeric width value: $2"
#          return 1
#        else
#          box_width="$2"
#          shift
#        fi
#        ;;
#      --top-padding) top_padding=true ;;
#      -*) log::error "invalid option: $1"; return 1 ;;
#      *) break ;;
#    esac
#    shift
#  done
#
#  : "${base_color:="$MSG_C_BASE"}"
#  : "${box_color:="$MSG_C_HIGHLIGHT1"}"
#  : "${prompt:=*}"
#
#  opts_prompt=( --prompt "$prompt" )
#
#  if [[ "${MSG_PYTHON3_UNAVAILABLE:-false}" == 'true' ]]; then
#    (( ${#logo_lines[@]} > 0 )) && {
#      MSG_INDENT=0 msg -b --no-prompt -c "$base_color" "$MSG_LOGO"
#      newline
#    }
#    for msg in "$@"; do
#      msg -b "${opts_prompt[@]}" -c "$base_color" "$msg"
#    done
#    return 0
#  fi
#
#  for line in "$@"; do
#    messages+=( "$line" )
#  done
#
#  # 表示幅の計算
#  # msg() に渡す文字列には `<hl></hl>` やエスケープシーケンスなどの
#  # 表示時の文字数に反映されない文字が含まれることがあるため、--plain で
#  # 装飾なしの実際に表示される文字列を取得して、表示幅を計算する。
#  # pythonが利用できる場合、unicodedataから表示幅を計算する。
#
#  msg::_box_calc_width() {
#    python3 - "$1" <<'PYTHON'
#import os, sys, unicodedata
#
#dotfiles_path = os.environ.get('DOTFILES_PATH')
#if dotfiles_path is None:
#  raise RuntimeError('DOTFILES_PATH is not set')
#
#sys.path.append(os.path.join(dotfiles_path, 'lib/python/_vendor'))
#from wcwidth import wcswidth
#
#s = sys.argv[1]
#w = wcswidth(s)
#if w >= 0:
#  print(w)
#  raise SystemExit
#PYTHON
#  }
#
#  for line in "${logo_lines[@]}"; do
#    plain_text="$(MSG_INDENT=0 msg --no-prompt --plain --strip "$line")"
#    len="$(msg::_box_calc_width "$plain_text")"
#    (( len > max )) && max="$len"
#  done
#
#  for line in "${messages[@]}"; do
#    plain_text="$(msg "${opts_prompt[@]}" --plain --strip "$line")"
#    len="$(msg::_box_calc_width "$plain_text")"
#    (( len > max )) && max="$len"
#  done
#
#  if [[ -n "${box_width:-}" ]]; then
#    max="$box_width"
#  elif [[ "$width_fit_mode" == 'full' ]]; then
#    term_width="$(tput cols)"
#    max=$(( $(tput cols) - padding * 2 - 2 ))
#  fi
#
#  log::debug "max: ${max}"
#
#  # boxの上面と底面を作成
#  local inner_width="$(( max + padding * 2 ))"
#  local top='┌' mid='│' bot='└'
#  local i
#
#  log::debug "inner_width: ${inner_width}"
#
#  for ((i=0; i<inner_width; i++)); do
#    top+='─'
#    bot+='─'
#  done
#  top+='┐'
#  bot+='┘'
#
#  msg::_box_line_padding() {
#    printf '%b│%*s%*s%*s│\n' "$box_color" \
#      "$padding" "" \
#      "$max" "" \
#      "$padding" ""
#  }
#
#  # 上面出力
#  printf '%b%s%b\n' "$box_color" "$top" "$ESC_RESET"
#
#  [[ "$top_padding" == 'true' ]] && msg::_box_line_padding
#
#  # logo出力
#  for line in "${logo_lines[@]}"; do
#    plain_text="$(MSG_INDENT=0 msg --no-prompt --plain --strip "$line")"
#    len="$(msg::_box_calc_width "$plain_text")"
#    printf '%b│%*s' "$box_color" "$padding" ""
#    MSG_INDENT=0 msg -b -n --no-prompt -c "$base_color" "$line"
#    printf '%*s' $(( max - len )) ""
#    printf '%*s%b│\n' "$padding" "" "$box_color"
#  done
#
#  [[ "$mid_padding" == 'true' ]] && msg::_box_line_padding
#
#  # 本文出力
#  for line in "${messages[@]}"; do
#    plain_text="$(msg "${opts_prompt[@]}" --plain --strip "$line")"
#    len="$(msg::_box_calc_width "$plain_text")"
#    printf '%b│%*s' "$box_color" "$padding" ""
#    msg -n "${opts_prompt[@]}" -c "$base_color" "$line"
#    printf '%*s' $(( max - len )) ""
#    printf '%*s%b│\n' "$padding" "" "$box_color"
#  done
#
#  [[ "$bot_padding" == 'true' ]] && msg::_box_line_padding
#
#  # 底面出力
#  printf '%b%s%b\n' "$box_color" "$bot" "$ESC_RESET"
#}

msg::read() {
  local input
  msg -n -B --prompt-color "$ESC_C_WARNING" --prompt='!' -- "$* " >/dev/tty
  IFS='' read -r input </dev/tty
  printf '%s' "$input"
}

msg::confirm() {
  local input mode tty_state

  case "${1:-notset}" in
    -r) mode='return'; shift ;;
    -y)
      mode='yes-or-no'
      [[ -z "${2:-}" ]] && abort "${1}: message required"
      shift
      ;;
    notset) abort 'option required' ;;
    *) abort "invalid option: $1" ;;
  esac

  case "$mode" in
    return)
      msg -B --prompt-color "$ESC_C_WARNING" --prompt='!' -- \
        'press <b><hl>RETURN/ENTER</hl></b> to continue or press any other key to abort.' \
        </dev/tty >/dev/tty

      # stdin flush
      read -sr -t 0.1 -N 255 _

      tty_state="$(/bin/stty -g)"
      /bin/stty raw -echo
      IFS='' read -r -n 1 -d '' -p 'ready?' input
      /bin/stty "$tty_state"
      newline

      if [[ "${input:-}" == $'\n' ]]; then
        return 0
      else
        return 1
      fi
      ;;
    yes-or-no)
      msg -n -B --prompt-color "$ESC_C_WARNING" --prompt='!' -- "$* [y/N] "
      # stdin flush
      read -sr -t 0.1 -N 255 _
      IFS='' read -r input
      if [[ "$input" =~ ^([Yy]|[Yy][Ee][Ss])$ ]]; then
        return 0
      else
        return 1
      fi
      ;;
  esac

  abort "invalid mode: ${mode}"
}

msg::marker() {
  local base_color prompt
  local newline=true
  local p
  while (( $# > 0 )); do
    case "$1" in
      --) shift; break ;;
      --complete)  base_color="$ESC_C_COMPLETE"; prompt='✨️' ;;
      --warning)   base_color="$ESC_C_WARNING";  prompt='⚡' ;;
      --terminate) base_color="$ESC_C_CRITICAL"; prompt='⛔' ;;
      -n) newline=false ;;
      -*) abort "invalid option: $1" ;;
      *) break ;;
    esac
    shift
  done
  msg::box --base-color="$base_color" --prompt="$prompt" -- "<b>$*</b>"
  [[ "$newline" == 'true' ]] && newline
  return 0
}

msg::notice() {
  local color event
  case "$1" in
    --configured) event='CONFIGURED'; color="$ESC_C_SUCCESS"; shift ;;
    --delete)     event='DELETE';     color="$ESC_C_DANGER";  shift ;;
    --ignore)     event='IGNORE';     color="$ESC_C_GRAYOUT"; shift ;;
    --link)       event='LINK';       color="$ESC_C_SUCCESS"; shift ;;
    --mkdir)      event='MKDIR';      color="$ESC_C_SUCCESS"; shift ;;
    --remove)     event='REMOVE';     color="$ESC_C_DANGER";  shift ;;
    --rmdir)      event='RMDIR';      color="$ESC_C_DANGER";  shift ;;
    --skip)       event='SKIP';       color="$ESC_C_NOTICE";  shift ;;
    --unlink)     event='UNLINK';     color="$ESC_C_DANGER";  shift ;;
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
