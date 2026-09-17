# shellcheck shell=bash

# @deps trap log theme

: "${MSG_DELAY:=0.1}"
: "${MSG_INDENT:=0}"
: "${MSG_BOX:=1}"

: "${MSG_PROMPT:=[>]}"
: "${MSG_PROMPT_HEADER:=###}"
: "${MSG_PROMPT_NOTICE:=[~]}"
: "${MSG_PROMPT_CHANGED:=[*]}"
: "${MSG_PROMPT_RM:=[/]}"
: "${MSG_PROMPT_SKIPPED:=[-]}"
: "${MSG_PROMPT_OK:=[^]}"
: "${MSG_PROMPT_WARNING:=[!]}"
: "${MSG_PROMPT_ERROR:=[;]}"
: "${MSG_PROMPT_CONFIRM:=[?]}"

msg::init() {
  (( ${MSG_INITIALIZED:-0} )) && return 0

  declare -g _MSG_LOG_CH_TOKENIZER='tokenizer'
  declare -g _MSG_LOG_CH_RENDERER='renderer'

  declare -gi _MSG_PYTHON3_UNAVAILABLE=0
  if ! python3 --version >/dev/null 2>&1; then
    _MSG_PYTHON3_UNAVAILABLE=1
    logger --warning 'python3 is not available. falling back to simplified mode.'
  fi

  declare -gi MSG_INITIALIZED=1
}

msg::_isinit() {
  if (( ${MSG_INITIALIZED:-0} )); then
    return 0
  else
    core::error 'not initialized'
    return 1
  fi
}

msg::newline() { printf '\n'; }

msg::_tokenizer_init() {
  declare -ga _MSG_TOKENIZER_OUTPUT_TYPE=()
  declare -ga _MSG_TOKENIZER_OUTPUT_VALUE=()
  declare -gA _MSG_TOKENIZER_OUTPUT_ATTR=()
  declare -gi _MSG_TOKENIZER_INITIALIZED=1
  logger --debug --ch="$_MSG_LOG_CH_TOKENIZER" 'MSG TOKENIZER INITIALIZED!'
}

msg::_tokenizer_isinit() {
  if (( ${_MSG_TOKENIZER_INITIALIZED:-0} )); then
    return 0
  else
    logger --error 'tokenizer is not initialized'
    return 1
  fi
}

msg::_peek_token_type_stack() {
  msg::_tokenizer_isinit || return 1

  local last_idx

  last_idx=$(( ${#_MSG_TOKENIZER_OUTPUT_TYPE[@]} - 1 ))
  if (( last_idx >= 0 )); then
    printf '%s' "${_MSG_TOKENIZER_OUTPUT_TYPE[last_idx]}"
  else
    printf ''
  fi
}

msg::_drop_token_stack() {
  msg::_tokenizer_isinit || return 1

  local last_idx type value key

  last_idx=$(( ${#_MSG_TOKENIZER_OUTPUT_TYPE[@]} - 1 ))
  if (( last_idx >= 0 )); then
    type="${_MSG_TOKENIZER_OUTPUT_TYPE[last_idx]}"
    value="${_MSG_TOKENIZER_OUTPUT_VALUE[last_idx]}"

    logger --debug --ch="$_MSG_LOG_CH_TOKENIZER" "type=\"${type}\" value=\"${value}\""

    unset '_MSG_TOKENIZER_OUTPUT_TYPE[last_idx]'
    unset '_MSG_TOKENIZER_OUTPUT_VALUE[last_idx]'
    for key in "${!_MSG_TOKENIZER_OUTPUT_ATTR[@]}"; do
      [[ $key == "${last_idx}:"* ]] || continue
      logger --debug --ch="$_MSG_LOG_CH_TOKENIZER" "index=\"${last_idx}\" key=\"${key}\""
      unset '_MSG_TOKENIZER_OUTPUT_ATTR[$key]'
    done
  fi

  #logger --debug --ch="$_MSG_LOG_CH_TOKENIZER" "$(declare -p _MSG_TOKENIZER_OUTPUT_TYPE)"
  #logger --debug --ch="$_MSG_LOG_CH_TOKENIZER" "$(declare -p _MSG_TOKENIZER_OUTPUT_VALUE)"
  #logger --debug --ch="$_MSG_LOG_CH_TOKENIZER" "$(declare -p _MSG_TOKENIZER_OUTPUT_ATTR)"
}

msg::_push_token_stack() {
  msg::_tokenizer_isinit || return 1
  # C形式の連鎖比較 `1 <= $# <= 3` は (1 <= $#) <= 3 と評価され常に真になるため、
  # 条件を分けて書く。
  (( $# >= 1 && $# <= 3 )) || { logger --error 'invalid options'; return 1; }

  local type="$1"
  local value="${2:-_}"
  local attrs="${3:-}"
  local re_attr='([a-zA-Z0-9_-]+)="([^"]+)"'

  logger --debug --ch="$_MSG_LOG_CH_TOKENIZER" "type=\"${type}\" value=\"${value}\""

  _MSG_TOKENIZER_OUTPUT_TYPE+=( "$type" )
  _MSG_TOKENIZER_OUTPUT_VALUE+=( "$value" )

  if [[ -n "$attrs" ]]; then
    local idx matched attr attr_value
    idx=$(( ${#_MSG_TOKENIZER_OUTPUT_TYPE[@]} - 1 ))
    while [[ "$attrs" =~ $re_attr ]]; do
      matched="${BASH_REMATCH[0]}"
      attr="${BASH_REMATCH[1]}"
      attr_value="${BASH_REMATCH[2]}"

      logger --debug --ch="$_MSG_LOG_CH_TOKENIZER" "index=\"${idx}\" attr=\"${attr}\" attr_value=\"${attr_value}\""

      _MSG_TOKENIZER_OUTPUT_ATTR["${idx}:${attr}"]="$attr_value"
      # matched をクォートしないとパターンとして解釈され、属性値に * や [ が
      # 含まれる場合に切り落としに失敗してこのループが終わらなくなる。
      attrs="${attrs#*"${matched}"}"
    done
  fi

  #logger --debug --ch="$_MSG_LOG_CH_TOKENIZER" "$(declare -p _MSG_TOKENIZER_OUTPUT_TYPE)"
  #logger --debug --ch="$_MSG_LOG_CH_TOKENIZER" "$(declare -p _MSG_TOKENIZER_OUTPUT_VALUE)"
  #logger --debug --ch="$_MSG_LOG_CH_TOKENIZER" "$(declare -p _MSG_TOKENIZER_OUTPUT_ATTR)"
}

msg::_tokenize_tag() {
  msg::_tokenizer_isinit || return 1
  (( $# != 1 )) && { logger --error 'invalid option'; return 1; }

  local re_tag='^<(/?@?[a-zA-Z0-9_-]+)( +.*)? *>$'
  local re_inline_tag='(b|it|hl)'
  local re_block_tag='@(noprompt|indent|b|it|hl|br)'
  local restore_newline=0
  local tag attrs top

  if [[ "$1" =~ $re_tag ]]; then
    tag="${BASH_REMATCH[1]}"
    attrs="${BASH_REMATCH[2]## }"
  else
    logger --error "invalid tag: $1"
    return 1
  fi

  logger --debug --ch="$_MSG_LOG_CH_TOKENIZER" "tag=\"${tag}\""

  if [[ ! "$tag" =~ ^/?(${re_inline_tag}|${re_block_tag})$ ]]; then
    logger --warning "unsupported tag: ${tag}"
    return 0
  fi

  case "$tag" in
    @*)
      case "$tag" in
        @noprompt) msg::_push_token_stack 'BLOCK_OPEN' 'noprompt' ;;
        @indent) msg::_push_token_stack 'BLOCK_OPEN' 'indent' "$attrs" ;;
        @b) msg::_push_token_stack 'BLOCK_OPEN' 'b' ;;
        @it) msg::_push_token_stack 'BLOCK_OPEN' 'it' ;;
        @hl) msg::_push_token_stack 'BLOCK_OPEN' 'hl' "$attrs" ;;
        @br) msg::_push_token_stack 'NEWLINE' ;;
      esac
      ;;
    /@*)
      top="$(msg::_peek_token_type_stack)"
      if [[ "$top" == 'NEWLINE' ]]; then
        restore_newline=1
        msg::_drop_token_stack
      fi

      case "$tag" in
        /@noprompt) msg::_push_token_stack 'BLOCK_CLOSE' 'noprompt' ;;
        /@indent) msg::_push_token_stack 'BLOCK_CLOSE' 'indent' ;;
        /@b) msg::_push_token_stack 'BLOCK_CLOSE' 'b' ;;
        /@it) msg::_push_token_stack 'BLOCK_CLOSE' 'it' ;;
        /@hl) msg::_push_token_stack 'BLOCK_CLOSE' 'hl' ;;
      esac

      if (( restore_newline )); then
        msg::_push_token_stack 'NEWLINE'
      fi
      ;;
    /*)
      case "$tag" in
        /hl|/b|/it) msg::_push_token_stack 'TAG_CLOSE' "${tag#/}" ;;
      esac
      ;;
    *)
      case "$tag" in
        hl|b|it) msg::_push_token_stack 'TAG_OPEN' "$tag" "$attrs" ;;
      esac
      ;;
  esac

  # 上のcaseが偽の条件で終わった場合に1を返さないようにする。
  # 呼び出し元 msg::_tokenize_line は set -e 下でこの戻り値を受けるため、
  # ここで1を返すとスクリプト全体が停止してしまう。
  return 0
}

msg::_tokenize_line() {
  msg::_tokenizer_isinit || return 1
  (( $# != 1 )) && { logger --error 'invalid option'; return 1; }

  local -a types=()
  local -a values=()
  local line="$1"
  local mode='TEXT'
  local text=
  local tag=
  local quote=
  local i c

  logger --debug --ch="$_MSG_LOG_CH_TOKENIZER" "input[${line}]"

  for (( i = 0; i < ${#line}; i++ )); do
    c="${line:i:1}"

    case "$mode" in
      TEXT)
        if [[ "$c" == '<' ]]; then
          if [[ -n "$text" ]]; then
            logger --debug --ch="$_MSG_LOG_CH_TOKENIZER" "│ TEXT=\"${text}\""
            types+=( 'TEXT' )
            values+=( "$text" )
          fi
          text=
          tag='<'
          mode='TAG'
        else
          text+="$c"
        fi
        ;;
      TAG)
        tag+="$c"
        if [[ "$c" == '"' ]]; then
          if [[ -z "$quote" ]]; then
            quote='"'
          else
            quote=
          fi
        elif [[ "$c" == '>' && -z "$quote" ]]; then
          logger --debug --ch="$_MSG_LOG_CH_TOKENIZER" "│ TAG=\"${tag}\""
          types+=( 'TAG' )
          values+=( "$tag" )
          tag=
          mode='TEXT'
        fi
        ;;
    esac
  done

  # タグが閉じられていない場合
  if [[ "$mode" == 'TAG' ]]; then
    text+="$tag"
  fi

  if [[ -n "$text" ]]; then
    logger --debug --ch="$_MSG_LOG_CH_TOKENIZER" "│ TEXT=\"${text}\""
    types+=( 'TEXT' )
    values+=( "$text" )
  fi

  logger --debug --ch="$_MSG_LOG_CH_TOKENIZER" '└'

  # 入力が空行かどうか
  local empty_line=0
  [[ -z "$line" ]] && empty_line=1

  # block tagのみの行かどうか
  local block_tag_only=1
  local re_space_only='^ *$'
  local re_block_tag='^</?@'
  if (( empty_line )); then
    block_tag_only=0
  else
    for i in "${!types[@]}"; do
      case "${types[i]}" in
        TEXT) [[ "${values[i]}" =~ $re_space_only ]] || block_tag_only=0 ;;
        TAG)  [[ "${values[i]}" =~ $re_block_tag ]]  || block_tag_only=0 ;;
        *)
          logger --error "invalid type: ${types[i]}"
          return 1
          ;;
      esac
    done
  fi

  logger --debug --ch="$_MSG_LOG_CH_TOKENIZER" \
    "empty_line=\"${empty_line}\" block_tag_only=\"${block_tag_only}\""

  (( block_tag_only )) || msg::_push_token_stack 'BEGIN_LINE'

  for i in "${!types[@]}"; do
    case "${types[i]}" in
      TAG) msg::_tokenize_tag "${values[i]}" ;;
      *) (( block_tag_only )) || msg::_push_token_stack "${types[i]}" "${values[i]}" ;;
    esac
  done

  (( block_tag_only )) || msg::_push_token_stack 'END_LINE'
  (( block_tag_only )) || msg::_push_token_stack 'NEWLINE'
}

msg::_tokenize() {
  msg::_tokenizer_isinit || return 1

  local raw="$1"
  local -a lines=()
  local line i

  while IFS= read -r line; do
    lines+=( "$line" )
  done <<<"$raw"

  if (( _MSG_RENDERER_CONTEXT['raw'] )); then
    msg::_push_token_stack 'BEGIN'
    msg::_push_token_stack 'TEXT' "$raw"
    msg::_push_token_stack 'NEWLINE'
    msg::_push_token_stack 'END'
    return 0
  fi

  msg::_push_token_stack 'BEGIN'

  for i in "${!lines[@]}"; do
    msg::_tokenize_line "${lines[i]}"
  done

  msg::_push_token_stack 'END'

  return 0
}

msg::_renderer_init() {
  declare -gA _MSG_RENDERER_CONTEXT=(
    ['prompt_symbol']="$MSG_PROMPT"
    ['prompt_style']='msg_prefix'
    ['indent_width']="$MSG_INDENT"
    ['plain']=0
    ['plain_prompt']=0
    ['raw']=0
    ['bold']=0
    ['base_style']='normal'
    ['highlight_style']='msg_highlight'
    ['newline']=1
    ['readline']=0
  )
  declare -ga _MSG_RENDERER_INLINE_STYLE_TAG_STACK=()
  declare -ga _MSG_RENDERER_INLINE_STYLE_STACK=()
  declare -ga _MSG_RENDERER_BLOCK_STYLE_TAG_STACK=()
  declare -ga _MSG_RENDERER_BLOCK_STYLE_STACK=()
  declare -ga _MSG_RENDERER_INDENT_STACK=()
  declare -g _MSG_RENDERER_PROMPT_STACK=()
  declare -g _MSG_RENDER_OUTPUT=
  declare -gi _MSG_RENDERER_INITIALIZED=1
  logger --debug --ch="$_MSG_LOG_CH_RENDERER" 'MSG RENDERER INITIALIZED!'
}

msg::_renderer_isinit() {
  if (( ${_MSG_RENDERER_INITIALIZED:-0} )); then
    return 0
  else
    logger --error 'renderer is not initialized'
    return 1
  fi
}

msg::_render_indent() {
  msg::_renderer_isinit || return 1

  local width="${_MSG_RENDERER_CONTEXT['indent_width']}"
  local item indent

  if [[ ! "$width" =~ ^[0-9]+$ ]]; then
    logger --error "invalid width. expected numeric value: ${width}"
    return 1
  fi

  for item in "${_MSG_RENDERER_INDENT_STACK[@]}"; do
    if (( item == 0 )); then
      width="${_MSG_RENDERER_CONTEXT['indent_width']}"
      break;
    fi
    (( width += item ))
  done

  logger --debug --ch="$_MSG_LOG_CH_RENDERER" "rendering indent: width=\"${width}\""

  indent="$(printf '%*s' "$width" '')"
  _MSG_RENDER_OUTPUT+="$indent"
}

msg::_render_append_escseq() {
  msg::_renderer_isinit || return 1

  if (( $# != 1 )); then
    logger --error "invalid option: ${1:-null}"
    return 1
  fi

  if (( _MSG_RENDERER_CONTEXT['readline'] )); then
    # 出力時に printf %b で変換すると本文中のバックスラッシュまで
    # 解釈されてしまうため、実際の制御文字をそのまま埋める。
    _MSG_RENDER_OUTPUT+=$'\x01'"${1}"$'\x02'
  else
    _MSG_RENDER_OUTPUT+="$1"
  fi
}

msg::_render_prompt() {
  msg::_renderer_isinit || return 1

  local last_idx=$(( ${#_MSG_RENDERER_PROMPT_STACK[@]} - 1 ))
  local prompt_style="${_MSG_RENDERER_CONTEXT['prompt_style']}"
  local prompt

  if (( last_idx < 0 )); then
    prompt="${_MSG_RENDERER_CONTEXT['prompt_symbol']}"
    logger --debug --ch="$_MSG_LOG_CH_RENDERER" "use default prompt: symbol=\"${prompt}\""
  else
    prompt="${_MSG_RENDERER_PROMPT_STACK[last_idx]}"
    logger --debug --ch="$_MSG_LOG_CH_RENDERER" "use prompt stack: index=\"${last_idx}\" symbol=\"${prompt}\""
  fi

  [[ -z "$prompt" ]] && return 0

  if (( ! _MSG_RENDERER_CONTEXT['plain_prompt'] )); then
    msg::_render_append_escseq "${STYLE_STDOUT[${prompt_style}]:-}"
  fi

  _MSG_RENDER_OUTPUT+="${prompt} "

  if (( ! _MSG_RENDERER_CONTEXT['plain_prompt'] )); then
    msg::_render_append_escseq "${STYLE_STDOUT['rst']:-}"
  fi
}

msg::_render_style() {
  msg::_renderer_isinit || return 1
  (( _MSG_RENDERER_CONTEXT['plain'] )) && return 0

  local base_style="${_MSG_RENDERER_CONTEXT['base_style']}"
  local style output i

  output+="${STYLE_STDOUT['rst']:-}${STYLE_STDOUT[${base_style}]:-}"

  if (( _MSG_RENDERER_CONTEXT['bold'] )); then
    output+="${STYLE_STDOUT['bold']:-}"
  fi

  # block tag stackを遡ってstyleを再描写
  for (( i = ${#_MSG_RENDERER_BLOCK_STYLE_TAG_STACK[@]} - 1; i >= 0; i-- )); do
    style="${_MSG_RENDERER_BLOCK_STYLE_STACK[i]}"
    output+="${STYLE_STDOUT[${style}]:-}"
  done

  # inline tag stackを遡ってstyleを再描写
  for (( i = ${#_MSG_RENDERER_INLINE_STYLE_TAG_STACK[@]} - 1; i >= 0; i-- )); do
    style="${_MSG_RENDERER_INLINE_STYLE_STACK[i]}"
    output+="${STYLE_STDOUT[${style}]:-}"
  done

  msg::_render_append_escseq "$output"
}

msg::_push_prompt_stack() {
  msg::_renderer_isinit || return 1
  (( $# != 1 )) && { logger --error 'invalid option'; return 1; }

  local symbol="$1"
  logger --debug --ch="$_MSG_LOG_CH_RENDERER" "symbol=\"${symbol}\""
  _MSG_RENDERER_PROMPT_STACK+=( "$symbol" )
}

msg::_drop_prompt_stack() {
  msg::_renderer_isinit || return 1
  (( ${#_MSG_RENDERER_PROMPT_STACK[@]} == 0 )) && return 0

  local last_idx=$(( ${#_MSG_RENDERER_PROMPT_STACK[@]} - 1 ))
  unset "_MSG_RENDERER_PROMPT_STACK[${last_idx}]"
}

msg::_push_indent_stack() {
  msg::_renderer_isinit || return 1
  (( $# != 1 )) && { logger --error 'invalid option'; return 1; }

  local width="$1"
  logger --debug --ch="$_MSG_LOG_CH_RENDERER" "width=\"${width}\""
  _MSG_RENDERER_INDENT_STACK+=( "$width" )
}

msg::_drop_indent_stack() {
  msg::_renderer_isinit || return 1
  (( ${#_MSG_RENDERER_INDENT_STACK[@]} == 0 )) && return 0

  local last_idx=$(( ${#_MSG_RENDERER_INDENT_STACK[@]} - 1 ))
  unset "_MSG_RENDERER_INDENT_STACK[${last_idx}]"
}

msg::_push_inline_style() {
  msg::_renderer_isinit || return 1
  (( $# != 2 )) && { logger --error 'invalid options'; return 1; }

  local tag="$1"
  local style="$2"

  logger --debug --ch="$_MSG_LOG_CH_RENDERER" "tag=\"${tag}\" style=\"${style}\""

  _MSG_RENDERER_INLINE_STYLE_TAG_STACK+=( "$tag" )
  _MSG_RENDERER_INLINE_STYLE_STACK+=( "$style" )

}

msg::_drop_inline_style() {
  msg::_renderer_isinit || return 1
  (( $# != 1 )) && { logger --error 'invalid option'; return 1; }

  local tag="$1"
  local i

  logger --debug --ch="$_MSG_LOG_CH_RENDERER" "tag=\"${tag}\""

  for (( i = ${#_MSG_RENDERER_INLINE_STYLE_TAG_STACK[@]} - 1; i >= 0; i-- )); do
    if [[ "${_MSG_RENDERER_INLINE_STYLE_TAG_STACK[i]}" == "$tag" ]]; then
      unset '_MSG_RENDERER_INLINE_STYLE_TAG_STACK[i]'
      unset '_MSG_RENDERER_INLINE_STYLE_STACK[i]'
      _MSG_RENDERER_INLINE_STYLE_TAG_STACK=( "${_MSG_RENDERER_INLINE_STYLE_TAG_STACK[@]}" )
      _MSG_RENDERER_INLINE_STYLE_STACK=( "${_MSG_RENDERER_INLINE_STYLE_STACK[@]}" )


      return 0
    fi
  done

  return 1
}

msg::_push_block_style() {
  msg::_renderer_isinit || return 1
  (( $# != 2 )) && { logger --error 'invalid options'; return 1; }

  local tag="$1"
  local style="$2"

  logger --debug --ch="$_MSG_LOG_CH_RENDERER" "tag=\"${tag}\" style=\"${style}\""

  _MSG_RENDERER_BLOCK_STYLE_TAG_STACK+=( "$tag" )
  _MSG_RENDERER_BLOCK_STYLE_STACK+=( "$style" )

}

msg::_drop_block_style() {
  msg::_renderer_isinit || return 1
  (( $# != 1 )) && { logger --error 'invalid option'; return 1; }

  local tag="$1"
  local i

  logger --debug --ch="$_MSG_LOG_CH_RENDERER" "tag=\"${tag}\""

  for (( i = ${#_MSG_RENDERER_BLOCK_STYLE_TAG_STACK[@]} - 1; i >= 0; i-- )); do
    if [[ "${_MSG_RENDERER_BLOCK_STYLE_TAG_STACK[i]}" == "$tag" ]]; then
      unset '_MSG_RENDERER_BLOCK_STYLE_TAG_STACK[i]'
      unset '_MSG_RENDERER_BLOCK_STYLE_STACK[i]'
      _MSG_RENDERER_BLOCK_STYLE_TAG_STACK=( "${_MSG_RENDERER_BLOCK_STYLE_TAG_STACK[@]}" )
      _MSG_RENDERER_BLOCK_STYLE_STACK=( "${_MSG_RENDERER_BLOCK_STYLE_STACK[@]}" )


      return 0
    fi
  done

  return 1
}

msg::_render_block_tag_open() {
  msg::_renderer_isinit || return 1
  (( $# != 1 )) && { logger --error 'invalid option'; return 1; }

  local idx="$1"
  local tag="${_MSG_TOKENIZER_OUTPUT_VALUE[idx]}"

  logger --debug --ch="$_MSG_LOG_CH_RENDERER" "token_index=\"${idx}\" tag=\"${tag}\""

  case "$tag" in
    noprompt)
      msg::_push_prompt_stack ''
      ;;
    indent)
      msg::_push_indent_stack "${_MSG_TOKENIZER_OUTPUT_ATTR[${idx}:width]:-0}"
      ;;
    b|it|hl) # style tags
      (( _MSG_RENDERER_CONTEXT['plain'] )) && return 0

      local ctx_style="${_MSG_RENDERER_CONTEXT['highlight_style']}"
      local style

      case "$tag" in
        b) style='bold' ;;
        it) style='italic' ;;
        hl) style="${_MSG_TOKENIZER_OUTPUT_ATTR[${idx}:style]:-${ctx_style}}" ;;
      esac

      msg::_push_block_style "$tag" "$style"
      ;;
    *)
      logger --error "invalid tag: ${tag}"
      ;;
  esac
}

msg::_render_block_tag_close() {
  msg::_renderer_isinit || return 1
  (( $# != 1 )) && { logger --error 'invalid options'; return 1; }

  local tag="$1"

  case "$tag" in
    noprompt)
      msg::_drop_prompt_stack
      ;;
    indent)
      msg::_drop_indent_stack
      ;;
    b|it|hl) # style tags
      # plain時は_render_block_tag_openがpushをスキップするため、
      # closeも同様にスキップする。ここを揃えないと、対応漏れとして
      # 検出されてしまう。(msg::_render_tag_close と同じ扱い)
      (( _MSG_RENDERER_CONTEXT['plain'] )) && return 0

      # 対応する開始タグがない場合、_drop_block_styleは1を返す。
      # タグの対応漏れでスクリプトを止めないよう、警告にとどめる。
      msg::_drop_block_style "$tag" \
        || logger --warning "unmatched block close tag: ${tag}"
      ;;
    *)
      logger --error "invalid tag: ${tag}"
      return 1
      ;;
  esac

  return 0
}

msg::_render_tag_open() {
  msg::_renderer_isinit || return 1
  (( $# != 1 )) && { logger --error 'invalid option'; return 1; }

  local idx="$1"
  local tag="${_MSG_TOKENIZER_OUTPUT_VALUE[idx]}"

  logger --debug --ch="$_MSG_LOG_CH_RENDERER" "token_index=\"${idx}\" tag=\"${tag}\""

  case "$tag" in
    b|hl|it) # style tags
      (( _MSG_RENDERER_CONTEXT['plain'] )) && return 0

      local ctx_style="${_MSG_RENDERER_CONTEXT['highlight_style']}"
      local style

      case "$tag" in
        b)  style='bold' ;;
        hl) style="${_MSG_TOKENIZER_OUTPUT_ATTR[${idx}:style]:-${ctx_style}}" ;;
        it) style='italic' ;;
      esac

      msg::_push_inline_style "$tag" "$style"
      msg::_render_append_escseq "${STYLE_STDOUT[${style}]:-}"
      ;;
    *)
      logger --error "invalid tag: ${tag}"
      ;;
  esac
}

msg::_render_tag_close() {
  msg::_renderer_isinit || return 1
  (( $# != 1 )) && { logger --error 'invalid options'; return 1; }

  local tag="$1"

  case "$tag" in
    b|hl|it) # style tags
      (( _MSG_RENDERER_CONTEXT['plain'] )) && return 0
      msg::_drop_inline_style "$tag"
      msg::_render_style
      ;;
    *)
      logger --error "invalid tag: ${tag}"
      ;;
  esac
}

msg::_render_token() {
  msg::_renderer_isinit || return 1
  msg::_tokenizer_isinit || return 1

  local i type value

  for i in "${!_MSG_TOKENIZER_OUTPUT_TYPE[@]}"; do
    type="${_MSG_TOKENIZER_OUTPUT_TYPE[i]}"
    value="${_MSG_TOKENIZER_OUTPUT_VALUE[i]}"

    logger --debug --ch="$_MSG_LOG_CH_RENDERER" "rendering token[${i}]: type=\"${type}\" value=\"${value}\""

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
        msg::_render_tag_open "$i"
        ;;
      TAG_CLOSE)
        msg::_render_tag_close "$value"
        ;;
      BLOCK_OPEN)
        msg::_render_block_tag_open "$i"
        ;;
      BLOCK_CLOSE)
        msg::_render_block_tag_close "$value"
        ;;
      END_LINE)
        # inline tagは行内でのみ有効なので行末で破棄する。
        # tag名とstyleは添字で対応する並列配列なので、必ず両方リセットする。
        # 片方だけ空にすると添字がずれ、次の行で別のstyleが復帰してしまう。
        _MSG_RENDERER_INLINE_STYLE_TAG_STACK=()
        _MSG_RENDERER_INLINE_STYLE_STACK=()
        if (( ! _MSG_RENDERER_CONTEXT['plain'] )); then
          msg::_render_append_escseq "${STYLE_STDOUT['rst']:-}"
        fi
        ;;
      NEWLINE)
        _MSG_RENDER_OUTPUT+=$'\n'
        ;;
      END)
        ;;
      *)
        logger --error "invalid token type: ${type}"
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

  logger --debug --ch="$_MSG_LOG_CH_RENDERER" "↓↓ input raw ↓↓
${raw}"
  logger --debug --ch="$_MSG_LOG_CH_RENDERER" "↑↑ input raw ↑↑"
  logger --debug --ch="$_MSG_LOG_CH_RENDERER" "$(declare -p '_MSG_RENDERER_CONTEXT')"

  msg::_tokenizer_init
  msg::_tokenize "$raw"
  msg::_render_token

  # 末尾の改行を除去
  if (( ! _MSG_RENDERER_CONTEXT['newline'] )); then
    _MSG_RENDER_OUTPUT="${_MSG_RENDER_OUTPUT%$'\n'}"
  fi

  # output
  logger --debug --ch="$_MSG_LOG_CH_RENDERER" "↓↓ rendering result ↓↓
$(printf '%q' "$_MSG_RENDER_OUTPUT")"
  logger --debug --ch="$_MSG_LOG_CH_RENDERER" "↑↑ rendering result ↑↑"
  # %b にすると本文のバックスラッシュが解釈されてしまう。
  # 制御文字はバッファ構築時に実文字で入れているため %s でよい。
  printf '%s' "$_MSG_RENDER_OUTPUT"

  return 0
}

msg() {
  # スクリプトのメッセージ出力に利用できます。
  # 引数にとった文字列をオプションに基づいて整形・色付けして出力します。
  # themeライブラリの `STYLE_STDOUT` を利用して標準出力に出力します。
  #
  # Environment Variables:
  #
  #   MSG_DELAY
  #        メッセージ出力後のsleepの秒数。
  #        標準出力がターミナルに接続していない場合は、`MSG_DELAY=0` で実行されます。
  #
  #   MSG_INDENT
  #        インデントの高さを数値で指定します(0でインデントなし)。
  #
  # Block Tags:
  #
  #   引数に取る文字列は以下のブロックタグを解釈します。
  #
  #     <@indent width="<width>">...</@indent>:
  #       区間のインデントを<width>でオーバーライドする。
  #
  #     <@noprompt>...</@noprompt>
  #       区間のプロンプトを非表示にする。
  #
  #     <@hl>...</@hl>
  #       区間の文字をハイライトする。
  #       style属性でstyle指定可能。
  #
  #     <@b>...</@b>
  #       区間の文字を太字にする。
  #
  #     <@b>...</@b>
  #       区間の文字をイタリック体にする。
  #
  #     <@br>
  #       改行を挿入する。
  #
  # Inline Tags:
  #
  #   引数に取る文字列は以下のインラインタグを解釈します。
  #   改行までの1行のなかでのみ有効です。
  #
  #     <hl>...</hl>: 囲まれた範囲の文字をハイライトする。
  #     <b>...</b>: 囲まれた範囲の文字を太字にする。
  #     <it>...</it>: 囲まれた範囲をイタリック体にする。
  #
  # Options:
  #   -b, --bold
  #
  #        メッセージ本文を太字で出力します。
  #
  #   -i, --indent <width>
  #
  #        インデント幅のデフォルトを数値で指定します。
  #        ブロックタグ <@indent width="<attrwidth>"> が指定された場合は
  #        <width> + <attrwidth> の幅でインデントされます。
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
  #   -R, --readline
  #
  #        readline用に制御コードSOH, STXをエスケープシーケンスに付与する。
  #
  #   -s, --base-style <style>
  #
  #        <style> 名を出力スタイルのデフォルトに設定します。
  #        このスタイルは、スタイルを操作するタグにオーバーライドされます。
  #
  #   -H, --highlight-style <style>
  #
  #        <style> 名を出力スタイルのデフォルトに設定します。
  #        このスタイルは、スタイルを操作するタグにオーバーライドされます。
  #
  #   --prompt <prompt string>
  #
  #        プロンプト文字列を指定します。
  #        デフォルト: `>`
  #
  #   --no-prompt
  #
  #        プロンプトなしで出力します。

  msg::_isinit || return 1
  msg::_renderer_init

  while (( $# > 0 )); do
    case "$1" in
      --)
        shift
        break
        ;;
      -b | --bold) _MSG_RENDERER_CONTEXT['bold']=1 ;;
      -i | --indent | --indent=*)
        if [[ "$1" =~ ^--indent= ]]; then
          _MSG_RENDERER_CONTEXT['indent_width']="${1#--indent=}"
        elif [[ -z "${2:-}" ]]; then
          logger --error 'missing indent width'
          return 1
        else
          _MSG_RENDERER_CONTEXT['indent_width']="$2"
          shift
        fi
        ;;
      -n) _MSG_RENDERER_CONTEXT['newline']=0 ;;
      -p | --plain) _MSG_RENDERER_CONTEXT['plain']=1 ;;
      -pp | --plain-prompt) _MSG_RENDERER_CONTEXT['plain_prompt']=1 ;;
      -ppp)
        _MSG_RENDERER_CONTEXT['plain']=1
        _MSG_RENDERER_CONTEXT['plain_prompt']=1
        ;;
      -r | --raw) _MSG_RENDERER_CONTEXT['raw']=1 ;;
      -R | --readline) _MSG_RENDERER_CONTEXT['readline']=1 ;;
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
          _MSG_RENDERER_CONTEXT['prompt_symbol']="${1#--prompt=}"
        elif [[ -z "${2:-}" ]]; then
          logger --error 'missing prompt symbol'
          return 1
        else
          _MSG_RENDERER_CONTEXT['prompt_symbol']="$2"
          shift
        fi
        ;;
      --prompt-style | --prompt-style=*)
        if [[ "$1" =~ ^--prompt-style= ]]; then
          _MSG_RENDERER_CONTEXT['prompt_style']="${1#--prompt-style=}"
        elif [[ -z "${2:-}" ]]; then
          logger --error 'missing prompt style'
          return 1
        else
          _MSG_RENDERER_CONTEXT['prompt_style']="$2"
          shift
        fi
        ;;
      --no-prompt) _MSG_RENDERER_CONTEXT['prompt_symbol']= ;;
      -*) logger --error "invalid option: $1"; return 1 ;;
      *) break ;;
    esac
    shift
  done

  msg::_render "${*:-}"

  [[ -t 1 ]] && sleep "$MSG_DELAY"

  return 0
}

msg::header() {
  msg \
    --prompt="$MSG_PROMPT_HEADER" \
    --prompt-style='msg_header' \
    --base-style='msg_header' \
    "$@"
}

msg::notice() {
  msg \
    --prompt="$MSG_PROMPT_NOTICE" \
    --prompt-style='msg_notice' \
    --base-style='msg_notice' \
    "$@"
}

msg::changed() {
  msg \
    --prompt="$MSG_PROMPT_CHANGED" \
    --prompt-style='msg_changed' \
    --base-style='msg_changed' \
    "$@"
}

msg::rm() {
  msg \
    --prompt="$MSG_PROMPT_RM" \
    --prompt-style='msg_rm' \
    --base-style='msg_rm' \
    "$@"
}

msg::ok() {
  msg \
    --prompt="$MSG_PROMPT_OK" \
    --prompt-style='msg_ok' \
    --base-style='msg_ok' \
    "$@"
}

msg::warning() {
  msg \
    --prompt="$MSG_PROMPT_WARNING" \
    --prompt-style='msg_warning' \
    --base-style='msg_warning' \
    "$@"
}

msg::error() {
  msg \
    --prompt="$MSG_PROMPT_ERROR" \
    --prompt-style='msg_error' \
    --base-style='msg_error' \
    "$@"
}

msg::skipped() {
  msg \
    --prompt="$MSG_PROMPT_SKIPPED" \
    --prompt-style='msg_skipped' \
    --base-style='msg_skipped' \
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
    --prompt="$MSG_PROMPT_CONFIRM" \
    --prompt-style='msg_prompt' \
    -- "$*"
  )"

  IFS='' read -r "${read_args[@]}" -p "$prompt_msg" input
  printf '%s' "$input"
}

msg::confirm() {
  if [[ ! -t 0 ]]; then
    logger --error 'standard input is not a terminal'
    return 1
  fi

  local input mode confirm_msg tty_state

  case "${1:-notset}" in
    --return|notset) mode='return'; shift ;;
    --yes-no)
      if [[ -z "${2:-}" ]]; then
        logger --error 'missing question message'
        return 1
      fi
      mode='yes-or-no'
      shift
      ;;
    *)
      logger --error "invalid option: $1"
      return 1
      ;;
  esac

  case "$mode" in
    return)
      confirm_msg='press <b><it>RETURN/ENTER</it></b> to continue or press any other key to abort.'
      msg -n \
        --prompt="$MSG_PROMPT_CONFIRM" \
        --prompt-style='msg_prompt' \
        -- "${confirm_msg} " </dev/tty >/dev/tty

      # stdin flush
      read -sr -t 0.1 -N 255 _

      tty_state="$(/bin/stty -g)"

      # raw中に中断されると端末がエコーなしのまま残るため、復帰処理を
      # トラップにも登録しておく。既存ハンドラは trap::concat で保持される。
      trap::save_handler 'EXIT' 'INT' 'TERM'
      trap::concat 'EXIT' "/bin/stty '${tty_state}'"
      trap::concat 'INT'  "/bin/stty '${tty_state}'"
      trap::concat 'TERM' "/bin/stty '${tty_state}'"

      /bin/stty raw -echo
      IFS='' read -r -n 1 -d '' -p 'ready? ' input
      /bin/stty "$tty_state"
      trap::restore_handler
      msg::newline

      if [[ "$input" == $'\n' ]]; then
        return 0
      else
        return 1
      fi
      ;;
    yes-or-no)
      while true; do
        msg -n \
          --prompt="$MSG_PROMPT_CONFIRM" \
          --prompt-style='msg_prompt' \
          -- "$* (y/n) " </dev/tty >/dev/tty

        # stdin flush
        read -sr -t 0.1 -N 255 _

        IFS='' read -r input
        if [[ "$input" =~ ^([Yy]|[Yy][Ee][Ss])$ ]]; then
          return 0
        elif [[ "$input" =~ ^([Nn]|[Nn][Oo])$ ]]; then
          return 1
        else
          msg::warning 'invalid input:('
          continue
        fi
      done
      ;;
    *)
      logger --error "invalid mode: ${mode}"
      return 1
      ;;
  esac

  return 1
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
    PS3="$(msg --prompt="$MSG_PROMPT_CONFIRM" --prompt-style='msg_prompt' -- "$ps")"
  fi
  COLUMNS=1

  select s in "$@"; do
    [[ "$REPLY" =~ ^[Qq](uit)?$ ]] && return 1
    [[ -z "$s" ]] && continue
    printf '%s' "$s"
    break
  done
}

msg::line() {
  local -r length="${1:-80}"
  local -r symbol='.'
  local line i

  # 端末以外では \r による上書きが効かず、各段階の出力がすべて連結されて
  # sum(1..length) 文字になってしまうため、アニメーションは行わない。
  if [[ ! -t 1 ]]; then
    line="$(msg::_repeat_char "$symbol" "$length")"
    printf '%s\n' "$line"
    return 0
  fi

  for (( i = 1; i <= length; i++ )); do
    line="$(msg::_repeat_char "$symbol" "$i")"
    printf "\r%s" "${STYLE_STDOUT['msg_line']:-}${line}${STYLE_STDOUT['rst']:-}"
    sleep 0.002
  done
  printf '\n'
}

msg::_repeat_char() {
  local char="$1"
  local count="$2"
  local output

  (( count < 0 )) && count=0

  printf -v output '%*s' "$count" ''
  printf '%s' "${output// /${char}}"
}

msg::_strip_escseq() {
  # 表示幅に影響しない制御文字を除去する
  #   - CSIシーケンス (色や属性)
  #   - readline用のSOH/STXマーカー (msg -R が付与する)
  #
  # 整形済み文字列の表示幅を測るために使う。

  printf '%s' "$1" \
    | sed -e $'s/\x1b\\[[0-9;:?]*[a-zA-Z]//g' -e $'s/[\x01\x02]//g'
}

msg::_calc_line_widths() {
  # 表示幅の計算
  # msg() に渡す文字列には `<hl></hl>` やエスケープシーケンスなどの
  # 表示時の文字数に反映されない文字が含まれることがあるため、--plain で
  # 装飾なしの実際に表示される文字列を取得して、表示幅を計算する。
  # pythonが利用できる場合、unicodedataから表示幅を計算する。
  #
  # 入力の各行に対して幅を1行ずつ出力する(入力と同じ行数)。
  # 行ごとにpython3を起動すると1行あたり30ms程度かかるため、まとめて処理する。

  python3 - "$1" <<'PYTHON'
import os
import sys

dotfiles_path = os.environ.get('DOTFILES_PATH')
if dotfiles_path is None:
  raise RuntimeError('DOTFILES_PATH is not set')

sys.path.insert(0, os.path.join(dotfiles_path, 'lib/python/_vendor'))

from wcwidth import wcswidth

if len(sys.argv) != 2:
  raise RuntimeError("usage: msg::_calc_line_widths <string>")

# splitlines()ではなくsplit('\n')を使うのは、空行を含めて入力と同じ行数を
# 返すため。呼び出し側は行数が一致することを前提にしている。
for line in sys.argv[1].split('\n'):
  w = wcswidth(line)

  if w < 0:
    escaped = line.encode("unicode_escape").decode()
    raise RuntimeError(f"string contains non-printable characters: {escaped}")

  print(w)
PYTHON
}

msg::box() {
  # Usage:
  #
  #   msg::box [box options] [msg options] -- <message>...
  #
  # Environment Variables:
  #
  #   MSG_BOX
  #        box表示を有効化する(0で非表示)。
  #        デフォルト: 1
  #
  # Options:
  #   `--` 以降の引数のメッセージをboxで囲んで出力します。
  #   `--box-*` はbox出力に関する動作を変更します。
  #   `--` 以前の `--box-*` 以外のオプションは `msg()` に直接渡されます。
  #
  #   --box-style
  #
  #        box枠のスタイル名を指定します。
  #        デフォルト: box
  #
  #   --box-padding-<top|bottom|left|right>
  #
  #        box枠の上下左右のパディング幅を指定します。
  #        デフォルト:
  #            box_padding_top=0
  #            box_padding_bottom=0
  #            box_padding_left=1
  #            box_padding_right=1
  #
  #   --box-rendered
  #
  #        引数を整形済みの文字列として扱い、msg() を通さずそのまま枠で囲みます。
  #        行ごとに異なるプロンプトやスタイルを使いたい場合に利用します。
  #        表示幅はエスケープシーケンスを除去して計算されるため、
  #        msg::rm や msg::skipped などの出力をそのまま渡せます。
  #
  #        例:
  #            content="$(
  #              msg::rm 'removed:'
  #              msg::skipped 'skipped:'
  #            )"
  #            msg::box --box-rendered -- "$content"
  #
  #        このモードでは `msg()` に渡すオプションは意味を持ちません。

  msg::_isinit || return 1

  local box_rendered=0
  local box_style='msg_box'
  local box_padding_top_default=1
  local box_padding_bottom_default=1
  local box_padding_left_default=2
  local box_padding_right_default=2
  local box_padding_fit=0
  local box_padding_nofit=0
  local -a msg_args=()
  local box_padding_top box_padding_bottom box_padding_left box_padding_right

  while (( $# > 0 )); do
    case "$1" in
      --) shift; break ;;
      --box-style | --box-style=*)
        if [[ "$1" =~ ^--box-style= ]]; then
          box_style="${1#--box-style=}"
        elif [[ -z "${2:-}" ]]; then
          logger --error "$1: missing box style"
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
          logger --error "$1: missing padding top"
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
          logger --error "$1: missing padding bottom"
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
          logger --error "$1: missing padding left"
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
          logger --error "$1: missing padding right"
          return 1
        else
          box_padding_right="$2"
          shift
        fi
        ;;
      --box-padding-fit) box_padding_fit=1 ;;
      --box-padding-nofit) box_padding_nofit=1 ;;
      --box-rendered) box_rendered=1 ;;
      *) msg_args+=( "$1" ) ;;
    esac
    shift
  done

  if (( box_padding_fit && box_padding_nofit )); then
    logger --error "--box-padding-fit and --box-padding-nofit options are mutually exclusive"
    return 1
  fi

  if \
    [[
      ! "${box_padding_top:-0}" =~ ^[0-9]+$ ||
      ! "${box_padding_bottom:-0}" =~ ^[0-9]+$ ||
      ! "${box_padding_left:-0}" =~ ^[0-9]+$ ||
      ! "${box_padding_right:-0}" =~ ^[0-9]+$
    ]]
  then
    logger --error 'invalid padding width option. expected numeric value.'
    return 1
  fi

  if (( box_rendered && ${#msg_args[@]} > 0 )); then
    logger --warning "--box-rendered: msg options are ignored: ${msg_args[*]}"
  fi

  # fallback
  # python3が利用できない場合、枠なしでそのまま出力する
  if (( _MSG_PYTHON3_UNAVAILABLE || ! MSG_BOX )); then
    local fallback
    for fallback in "$@"; do
      if (( box_rendered )); then
        printf '%s\n' "$fallback"
      else
        msg "${msg_args[@]}" -- "$fallback"
      fi
    done
    return 0
  fi

  local -a inner_rendered_lines=()
  local -a inner_line_widths=()
  local max_width=0
  local count_line=0
  local str i line
  local rendered rendered_plain widths width rule pad

  for str in "$@"; do
    if (( box_rendered )); then
      # 整形済みなので msg() は通さず、幅計算用にエスケープシーケンスだけ落とす
      logger --debug 'using pre-rendered message...'
      rendered="$str"
      rendered_plain="$(msg::_strip_escseq "$str")"
    else
      logger --debug 'rendering messages...'
      rendered="$(msg "${msg_args[@]}" -- "$str")"

      logger --debug 'rendering plain messages...'
      rendered_plain="$(msg -ppp "${msg_args[@]}" -- "$str")"
    fi

    while IFS= read -r line; do
      inner_rendered_lines+=( "$line" )
      count_line=$(( count_line + 1 ))
    done <<<"$rendered"

    logger --debug 'calculating line widths...'
    if ! widths="$(msg::_calc_line_widths "$rendered_plain")"; then
      logger --error 'failed to calculate line widths'
      return 1
    fi

    while IFS= read -r width; do
      inner_line_widths+=( "$width" )
      (( width > max_width )) && max_width="$width"
    done <<<"$widths"
  done

  logger --debug "line count: ${count_line}"
  logger --debug "max width: ${max_width}"

  if (( count_line == 1 && ! box_padding_nofit )); then
    box_padding_fit=1
  fi

  logger --debug "box_padding_fit: ${box_padding_fit}"

  if (( box_padding_fit )); then
    : "${box_padding_top:=0}"
    : "${box_padding_bottom:=0}"
    : "${box_padding_left:=1}"
    : "${box_padding_right:=1}"
  fi

  : "${box_padding_top:=${box_padding_top_default}}"
  : "${box_padding_bottom:=${box_padding_bottom_default}}"
  : "${box_padding_left:=${box_padding_left_default}}"
  : "${box_padding_right:=${box_padding_right_default}}"

  rule="$(msg::_repeat_char '─' "$(( max_width + box_padding_left + box_padding_right ))")"

  # top
  printf '%s┌%s┐\n' "${STYLE_STDOUT[${box_style}]:-}" "$rule"

  # padding top
  for (( i = 0; i < box_padding_top; i++ )); do
    printf '%s│%*s│\n' \
      "${STYLE_STDOUT[${box_style}]:-}" \
      "$(( max_width + box_padding_left + box_padding_right ))" ''
  done

  # body
  for i in "${!inner_rendered_lines[@]}"; do
    pad="$(( max_width - inner_line_widths[i] ))"

    printf '│%*s%s%*s%*s%s│\n' \
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
  printf '└%s┘%s\n' "$rule" "${STYLE_STDOUT['rst']:-}"

  #[[ -t 1 ]] && sleep "$MSG_DELAY"

  return 0
}
