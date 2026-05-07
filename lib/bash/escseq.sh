# shellcheck shell=bash
# shellcheck disable=SC2034
LIB_DEPS=( core )
[[ ${1:-} = __META_PROBE__ ]] && return 0

escseq::_print_csi() { printf '\033[%sm' "$1"; }

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
  local -r fg_black=30
  local -r fg_red=31
  local -r fg_green=32
  local -r fg_yellow=33
  local -r fg_blue=34
  local -r fg_magenta=35
  local -r fg_cyan=36
  local -r fg_white=37
  local -r fg_set_color=38
  local -r fg_default=39
  local -r bg_black=40
  local -r bg_red=41
  local -r bg_green=42
  local -r bg_yellow=43
  local -r bg_blue=44
  local -r bg_magenta=45
  local -r bg_cyan=46
  local -r bg_white=47
  local -r bg_set_color=48
  local -r bg_default=49
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
    escseq::_print_csi "$reset"
    return 0
  fi

  local code_arr=()
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
      --default-intencity)  code_arr+=( "$default_intensity" ) ;;

      # named colors
      --black)           code_arr+=( "$fg_black" ) ;;
      --red)             code_arr+=( "$fg_red" ) ;;
      --green)           code_arr+=( "$fg_green" ) ;;
      --yellow)          code_arr+=( "$fg_yellow" ) ;;
      --blue)            code_arr+=( "$fg_blue" ) ;;
      --magenta)         code_arr+=( "$fg_magenta" ) ;;
      --cyan)            code_arr+=( "$fg_cyan" ) ;;
      --white)           code_arr+=( "$fg_white" ) ;;
      --default)         code_arr+=( "$fg_default" ) ;;
      --bright-black)    code_arr+=( "$fg_bright_black" ) ;;
      --bright-red)      code_arr+=( "$fg_bright_red" ) ;;
      --bright-green)    code_arr+=( "$fg_bright_green" );;
      --bright-yellow)   code_arr+=( "$fg_bright_yellow" ) ;;
      --bright-blue)     code_arr+=( "$fg_bright_blue" ) ;;
      --bright-magenta)  code_arr+=( "$fg_bright_magenta" ) ;;
      --bright-cyan)     code_arr+=( "$fg_bright_cyan" ) ;;
      --bright-white)    code_arr+=( "$fg_bright_white" ) ;;

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
      --fg-rgb)
        if [[ -z "${2:-}" ]]; then
          core::error "color code required: $1"
        elif [[ "$2" =~ ^[0-9]+(:|;)[0-9]+(:|;)[0-9]+$ ]]; then
          code_arr+=( "${fg_set_color};2;${2//:/;}" )
          shift
        else
          core::error "$1: invalid color code (expected: \"r:g:b\" or \"r;g;b\"): $2"
        fi
        ;;
      --bg-rgb)
        if [[ -z "${2:-}" ]]; then
          core::error "color code required: $1"
        elif [[ "$2" =~ ^[0-9]+(:|;)[0-9]+(:|;)[0-9]+$ ]]; then
          code_arr+=( "${bg_set_color};2;${2//:/;}" )
          shift
        else
          core::error "$1: invalid color code (expected: \"r:g:b\"): $2"
        fi
        ;;

      *) core::error "illegal option: $1" ;;
    esac
    shift
  done

  local joined_code
  IFS=';' joined_code="${code_arr[*]}"
  escseq::_print_csi "$joined_code"
}
