# shellcheck shell=bash

# @deps core

# Escape Sequence <escseq.sh>
#
# References:
#   - https://en.wikipedia.org/wiki/ANSI_escape_code
#   - https://akinomyoga.github.io/contra/escseq.html

ESCSEQ_ESC="$(printf '\x1b')"

# SGR パラメータの一覧。`escseq::sgr --<キー>` で指定する。
declare -grA ESCSEQ_SGR=(
  ['reset']=0

  ['bold']=1
  ['faint']=2
  ['italic']=3
  ['underline']=4
  ['blink']=5
  ['rapid-blink']=6
  ['reverse']=7
  ['conceal']=8
  ['strike']=9

  ['default-intensity']=22
  ['noitalic']=23
  ['nounderline']=24
  ['noblink']=25
  ['noreverse']=27
  ['reveal']=28
  ['nostrike']=29

  ['black']=30
  ['red']=31
  ['green']=32
  ['yellow']=33
  ['blue']=34
  ['magenta']=35
  ['cyan']=36
  ['white']=37
  ['fg-set-color']=38
  ['default-fg']=39

  ['bg-black']=40
  ['bg-red']=41
  ['bg-green']=42
  ['bg-yellow']=43
  ['bg-blue']=44
  ['bg-magenta']=45
  ['bg-cyan']=46
  ['bg-white']=47
  ['bg-set-color']=48
  ['default-bg']=49

  ['bright-black']=90
  ['bright-red']=91
  ['bright-green']=92
  ['bright-yellow']=93
  ['bright-blue']=94
  ['bright-magenta']=95
  ['bright-cyan']=96
  ['bright-white']=97

  ['bg-bright-black']=100
  ['bg-bright-red']=101
  ['bg-bright-green']=102
  ['bg-bright-yellow']=103
  ['bg-bright-blue']=104
  ['bg-bright-magenta']=105
  ['bg-bright-cyan']=106
  ['bg-bright-white']=107
)

escseq::csi() {
  local -r csi="${ESCSEQ_ESC}\x5b"
  local -r sgr='\x6d'

  local type

  if (( $# != 2 )); then
    core::error 'usage: escseq::csi <type> <parameter string>'
    return 1
  fi

  case "$1" in
    --sgr) type="$sgr" ;;
    *)
      core::error "invalid type: $1"
      return 1
      ;;
  esac
  shift

  printf '%b%s%b' "$csi" "${1:-}" "$type"
}

escseq::_hexcc2rgb() {
  local cc="${1#\#}"
  if [[ ! "$cc" =~ ^[0-9a-fA-F]{6}$ ]]; then
    core::error "invalid colorcode format: ${cc}"
    return 1
  fi
  printf '%d;%d;%d' \
    "0x${cc:0:2}" \
    "0x${cc:2:2}" \
    "0x${cc:4:2}"
}

escseq::_sgr_color_code() {
  # usage: escseq::_sgr_color_code <オプション> <色>
  #
  # 色に引数を取るオプションの SGR パラメータを組み立てて出力する。
  # 前景か背景かを表すコードに、8bit なら `;5;<n>`、true color なら
  # `;2;<r>;<g>;<b>` が続く。

  local opt="$1" value="$2" base rgb

  case "$opt" in
    --fg-*) base="${ESCSEQ_SGR['fg-set-color']}" ;;
    --bg-*) base="${ESCSEQ_SGR['bg-set-color']}" ;;
    *)
      core::error "invalid option: ${opt}"
      return 1
      ;;
  esac

  if [[ "$opt" == *-256 ]]; then
    if [[ ! "$value" =~ ^[0-9]+$ ]]; then
      core::error "${opt}: invalid color code: ${value}"
      return 1
    fi
    printf '%s;5;%s' "$base" "$value"
    return 0
  fi

  if [[ "$value" =~ ^[0-9]+(:|;)[0-9]+(:|;)[0-9]+$ ]]; then
    printf '%s;2;%s' "$base" "${value//:/;}"
    return 0
  fi

  if [[ "$value" =~ ^#?[0-9a-fA-F]{6}$ ]]; then
    rgb="$(escseq::_hexcc2rgb "$value")" || return 1
    printf '%s;2;%s' "$base" "$rgb"
    return 0
  fi

  core::error "${opt}: invalid color code (expected: \"R:G:B\" or \"#RRGGBB\"): ${value}"
  return 1
}

escseq::sgr() {
  if (( $# == 0 )); then
    escseq::csi --sgr "${ESCSEQ_SGR['reset']}"
    return 0
  fi

  local code invalid=0
  local -a code_arr=()

  while (( $# > 0 )); do
    case "$1" in
      --fg-256 | --bg-256 | --fg-tc | --bg-tc)
        if (( $# < 2 )); then
          core::error "missing color argument: $1"
          invalid=1
        else
          if code="$(escseq::_sgr_color_code "$1" "$2")"; then
            code_arr+=( "$code" )
          else
            invalid=1
          fi
          shift
        fi
        ;;
      --*)
        code="${ESCSEQ_SGR[${1#--}]:-}"
        if [[ -n "$code" ]]; then
          code_arr+=( "$code" )
        else
          core::error "illegal option: $1"
          invalid=1
        fi
        ;;
      *)
        core::error "illegal option: $1"
        invalid=1
        ;;
    esac
    shift
  done

  # 不正な引数があった場合、部分的に組み立てたシーケンスは出力せず失敗を返す。
  # 呼び出し側(theme等)がコマンド置換で受けるため、黙って壊れた値を渡さない。
  if (( invalid )); then
    return 1
  fi

  # IFS はこの関数内でのみ有効にする。代入のみのコマンドに前置した IFS は
  # カレントシェルに残り続けるため、local で宣言してから join する。
  local IFS=';'
  local joined_code="${code_arr[*]}"
  escseq::csi --sgr "$joined_code"
}
