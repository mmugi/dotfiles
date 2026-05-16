# shellcheck shell=bash

LIB_VERSION='1.0.0'
LIB_DEPS=( core )
[[ "${1:-}" = '__IMPORT__' ]] && return 0

# Escape Sequence <escseq.sh>
#
# References:
#   - https://en.wikipedia.org/wiki/ANSI_escape_code
#   - https://akinomyoga.github.io/contra/escseq.html

ESCSEQ_ESC="$(printf '\x1b')"

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

escseq::sgr() {
  local -r reset=0
  local -r bold=1
  local -r faint=2
  local -r italic=3
  local -r underline=4
  local -r blink=5
  local -r rapid_blink=6
  local -r reverse=7
  local -r conceal=8
  local -r strike=9
  local -r default_intensity=22
  local -r noitalic=23
  local -r nounderline=24
  local -r noblink=25
  local -r noreverse=27
  local -r reveal=28
  local -r nostrike=29
  local -r fg_black=30
  local -r fg_red=31
  local -r fg_green=32
  local -r fg_yellow=33
  local -r fg_blue=34
  local -r fg_magenta=35
  local -r fg_cyan=36
  local -r fg_white=37
  local -r fg_set_color=38
  local -r default_fg=39
  local -r bg_black=40
  local -r bg_red=41
  local -r bg_green=42
  local -r bg_yellow=43
  local -r bg_blue=44
  local -r bg_magenta=45
  local -r bg_cyan=46
  local -r bg_white=47
  local -r bg_set_color=48
  local -r default_bg=49
  local -r fg_bright_black=90
  local -r fg_bright_red=91
  local -r fg_bright_green=92
  local -r fg_bright_yellow=93
  local -r fg_bright_blue=94
  local -r fg_bright_magenta=95
  local -r fg_bright_cyan=96
  local -r fg_bright_white=97
  local -r bg_bright_black=100
  local -r bg_bright_red=101
  local -r bg_bright_green=102
  local -r bg_bright_yellow=103
  local -r bg_bright_blue=104
  local -r bg_bright_magenta=105
  local -r bg_bright_cyan=106
  local -r bg_bright_white=107

  if (( $# == 0 )); then
    escseq::csi --sgr "$reset"
    return 0
  fi

  local rgb code_arr=()
  while (( $# > 0 )); do
    case "$1" in
      # attributes
      --reset)              code_arr+=( "$reset" ) ;;

      --bold)               code_arr+=( "$bold" ) ;;
      --faint)              code_arr+=( "$faint" ) ;;
      --italic)             code_arr+=( "$italic" ) ;;
      --underline)          code_arr+=( "$underline" ) ;;
      --blink)              code_arr+=( "$blink" ) ;;
      --rapid_blink)        code_arr+=( "$rapid_blink" ) ;;
      --reverse)            code_arr+=( "$reverse" ) ;;
      --conceal)            code_arr+=( "$conceal" ) ;;
      --strike)             code_arr+=( "$strike" ) ;;

      --default-intensity)  code_arr+=( "$default_intensity" ) ;;
      --noitalic)           code_arr+=( "$noitalic" ) ;;
      --nounderline)        code_arr+=( "$nounderline" ) ;;
      --noblink)            code_arr+=( "$noblink" ) ;;
      --noreverse)          code_arr+=( "$noreverse" ) ;;
      --reveal)             code_arr+=( "$reveal" ) ;;
      --nostrike)           code_arr+=( "$nostrike" ) ;;

      # named colors (4bit colors)
      --black)              code_arr+=( "$fg_black" ) ;;
      --red)                code_arr+=( "$fg_red" ) ;;
      --green)              code_arr+=( "$fg_green" ) ;;
      --yellow)             code_arr+=( "$fg_yellow" ) ;;
      --blue)               code_arr+=( "$fg_blue" ) ;;
      --magenta)            code_arr+=( "$fg_magenta" ) ;;
      --cyan)               code_arr+=( "$fg_cyan" ) ;;
      --white)              code_arr+=( "$fg_white" ) ;;

      --default-fg)         code_arr+=( "$default_fg" ) ;;

      --bg-black)           code_arr+=( "$bg_black" ) ;;
      --bg-red)             code_arr+=( "$bg_red" ) ;;
      --bg-green)           code_arr+=( "$bg_green" ) ;;
      --bg-yellow)          code_arr+=( "$bg_yellow" ) ;;
      --bg-blue)            code_arr+=( "$bg_blue" ) ;;
      --bg-magenta)         code_arr+=( "$bg_magenta" ) ;;
      --bg-cyan)            code_arr+=( "$bg_cyan" ) ;;
      --bg-white)           code_arr+=( "$bg_white" ) ;;

      --default-bg)         code_arr+=( "$default_bg" ) ;;

      --bright-black)       code_arr+=( "$fg_bright_black" ) ;;
      --bright-red)         code_arr+=( "$fg_bright_red" ) ;;
      --bright-green)       code_arr+=( "$fg_bright_green" );;
      --bright-yellow)      code_arr+=( "$fg_bright_yellow" ) ;;
      --bright-blue)        code_arr+=( "$fg_bright_blue" ) ;;
      --bright-magenta)     code_arr+=( "$fg_bright_magenta" ) ;;
      --bright-cyan)        code_arr+=( "$fg_bright_cyan" ) ;;
      --bright-white)       code_arr+=( "$fg_bright_white" ) ;;

      --bg-bright-black)    code_arr+=( "$bg_bright_black" ) ;;
      --bg-bright-red)      code_arr+=( "$bg_bright_red" ) ;;
      --bg-bright-green)    code_arr+=( "$bg_bright_green" );;
      --bg-bright-yellow)   code_arr+=( "$bg_bright_yellow" ) ;;
      --bg-bright-blue)     code_arr+=( "$bg_bright_blue" ) ;;
      --bg-bright-magenta)  code_arr+=( "$bg_bright_magenta" ) ;;
      --bg-bright-cyan)     code_arr+=( "$bg_bright_cyan" ) ;;
      --bg-bright-white)    code_arr+=( "$bg_bright_white" ) ;;

      # 8bit colors
      --fg-256)
        if [[ -z "${2:-}" ]]; then
          core::error "color code required: $1"
        elif [[ "$2" =~ ^[0-9]+$ ]]; then
          code_arr+=( "${fg_set_color};5;$2" )
          shift
        else
          core::error "$1: invalid color code: $2"
        fi
        ;;
      --bg-256)
        if [[ -z "${2:-}" ]]; then
          core::error "color code required: $1"
        elif [[ "$2" =~ ^[0-9]+$ ]]; then
          code_arr+=( "${bg_set_color};5;$2" )
          shift
        else
          core::error "$1: invalid color code: $2"
        fi
        ;;

      # true colors
      --fg-tc)
        if [[ -z "${2:-}" ]]; then
          core::error "missing color argument: $1"
        elif [[ "$2" =~ ^[0-9]+(:|;)[0-9]+(:|;)[0-9]+$ ]]; then
          code_arr+=( "${fg_set_color};2;${2//:/;}" )
          shift
        elif [[ "$2" =~ ^#?[0-9a-zA-Z]{6}$ ]]; then
          rgb="$(escseq::_hexcc2rgb "$2")"
          code_arr+=( "${fg_set_color};2;${rgb}" )
          shift
        else
          core::error "$1: invalid color code (expected: \"R:G:B\" or \"#RRGGBB\"): $2"
        fi
        ;;
      --bg-tc)
        if [[ -z "${2:-}" ]]; then
          core::error "missing color argument: $1"
        elif [[ "$2" =~ ^[0-9]+(:|;)[0-9]+(:|;)[0-9]+$ ]]; then
          code_arr+=( "${bg_set_color};2;${2//:/;}" )
          shift
        elif [[ "$2" =~ ^#?[0-9a-zA-Z]{6}$ ]]; then
          rgb="$(escseq::_hexcc2rgb "$2")"
          code_arr+=( "${bg_set_color};2;${rgb}" )
          shift
        else
          core::error "$1: invalid color code (expected: \"R:G:B\" or \"#RRGGBB\"): $2"
        fi
        ;;
      *) core::error "illegal option: $1" ;;
    esac
    shift
  done

  local joined_code
  IFS=';' joined_code="${code_arr[*]}"
  escseq::csi --sgr "$joined_code"
}
