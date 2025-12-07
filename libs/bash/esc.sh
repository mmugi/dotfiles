#!/usr/bin/env bash

: LIBRARY METADATA
# shellcheck disable=SC2034
{
  LIB_VERSION='1.0.0'
  LIB_DEPS=()
  [[ ${1:-} = __META_PROBE__ ]] && return 0
}

: "${COLOR_MODE:=auto}"   # COLOR_MODE: auto / always / never

esc::_print_esc() {
  local code=()
  for arg in "$@"; do [[ -n "$arg" ]] && code+=("$arg"); done
  local IFS=';'
  printf '\033[%sm' "${code[*]:-}"
}

esc::_colors_supported() {
  [[ -n "${NO_COLOR:-}" ]] && return 1
  case "${COLOR_MODE}" in
    always) return 0 ;;
    never)  return 1 ;;
  esac
  [[ -t 1 ]] || return 1
  return 0
}

esc::_colors_supported_stderr() {
  [[ -n "${NO_COLOR:-}" ]] && return 1
  case "${COLOR_MODE}" in
    always) return 0 ;;
    never)  return 1 ;;
  esac
  [[ -t 2 ]] || return 1
  return 0
}

esc::sgr() {
  # attributes
  local -r reset_attr='0'
  local -r bold='1'
  local -r faint='2'
  local -r italic='3'
  local -r underline='4'
  local -r blink='5'
  local -r fast_blink='6'
  local -r reverse='7'
  local -r conceal='8'
  local -r strike='9'
  local -r reset_intensity='22'

  # colors
  local -r black='30'
  local -r red='31'
  local -r green='32'
  local -r yellow='33'
  local -r blue='34'
  local -r magenta='35'
  local -r cyan='36'
  local -r white='37'
  local -r default='39'

  local -r reset_all="${reset_attr};${default}"

  if [[ $# -eq 0 ]]; then
    esc::_print_esc "$reset_all"
    return 0
  fi

  local code_color
  local code_attr_arr=()
  while (( $# > 0 )); do
    case "$1" in
      # colors
      black)    code_color="$black" ;;
      red)      code_color="$red" ;;
      green)    code_color="$green" ;;
      yellow)   code_color="$yellow" ;;
      blue)     code_color="$blue" ;;
      magenta)  code_color="$magenta" ;;
      cyan)     code_color="$cyan" ;;
      white)    code_color="$white" ;;
      default)  code_color="$default" ;;
      [0-9]*)   code_color="38;5;$1" ;;

      # attributes
      reset_attr)  code_attr_arr+=("$reset_attr") ;;
      reset_ie)    code_attr_arr+=("$reset_intensity") ;;
      bold)        code_attr_arr+=("$bold") ;;
      faint)       code_attr_arr+=("$faint") ;;
      italic)      code_attr_arr+=("$italic") ;;
      underline)   code_attr_arr+=("$underline") ;;
      blink)       code_attr_arr+=("$blink") ;;
      fast_blink)  code_attr_arr+=("$fast_blink") ;;
      reverse)     code_attr_arr+=("$reverse") ;;
      conceal)     code_attr_arr+=("$conceal") ;;
      strike)      code_attr_arr+=("$strike") ;;

      *) log_error "illegal option: $1" ;;
    esac
    shift
  done

  local -r code_attr=$(IFS=';'; echo "${code_attr_arr[*]:-}")
  esc::_print_esc "$code_attr" "${code_color:-}"
}

# shellcheck disable=SC2034
if esc::_colors_supported; then
  ESC_RESET="$(esc::sgr)"

  # attributes
  ESC_ATTR_RESET="$(esc::sgr reset_attr)"
  ESC_ATTR_BOLD="$(esc::sgr bold)"
  ESC_ATTR_FAINT="$(esc::sgr faint)"
  ESC_ATTR_ITALIC="$(esc::sgr italic)"
  ESC_ATTR_UNDERLINE="$(esc::sgr underline)"
  ESC_ATTR_BLINK="$(esc::sgr blink)"
  ESC_ATTR_FAST_BLINK="$(esc::sgr fast_blink)"
  ESC_ATTR_REVERSE="$(esc::sgr reverse)"
  ESC_ATTR_CONCEAL="$(esc::sgr conceal)"
  ESC_ATTR_STRIKE="$(esc::sgr strike)"
  ESC_ATTR_RESET_IE="$(esc::sgr reset_ie)"

  # color palette
  ESC_FG_DEFAULT="$(esc::sgr 39)"
  ESC_FG_GRAY="$(esc::sgr 103)"
  ESC_FG_RED="$(esc::sgr  166)"
  ESC_FG_RED="$(esc::sgr  167)"
  ESC_FG_BLUE="$(esc::sgr 75)"
  ESC_FG_YELLOW="$(esc::sgr 220)"
  ESC_FG_CYAN="$(esc::sgr 195)"
  ESC_FG_PINK="$(esc::sgr 175)"
  ESC_FG_PURPLE="$(esc::sgr 105)"
  ESC_FG_LIME="$(esc::sgr 155)"
  ESC_FG_DARKGREEN="$(esc::sgr 36)"
else
  ESC_RESET=

  # attributes
  ESC_ATTR_RESET=
  ESC_ATTR_BOLD=
  ESC_ATTR_FAINT=
  ESC_ATTR_ITALIC=
  ESC_ATTR_UNDERLINE=
  ESC_ATTR_BLINK=
  ESC_ATTR_FAST_BLINK=
  ESC_ATTR_REVERSE=
  ESC_ATTR_CONCEAL=
  ESC_ATTR_STRIKE=
  ESC_ATTR_RESET_IE=

  # color palette
  ESC_FG_DEFAULT=
  ESC_FG_GRAY=
  ESC_FG_RED=
  ESC_FG_BLUE=
  ESC_FG_YELLOW=
  ESC_FG_CYAN=
  ESC_FG_PINK=
  ESC_FG_PURPLE=
  ESC_FG_LIME=
  ESC_FG_DARKGREEN=
fi

# shellcheck disable=SC2034
if esc::_colors_supported_stderr; then
  ESC_STDERR_RESET="$(esc::sgr)"

  # attributes
  ESC_STDERR_ATTR_RESET="$(esc::sgr reset_attr)"
  ESC_STDERR_ATTR_BOLD="$(esc::sgr bold)"
  ESC_STDERR_ATTR_FAINT="$(esc::sgr faint)"
  ESC_STDERR_ATTR_ITALIC="$(esc::sgr italic)"
  ESC_STDERR_ATTR_UNDERLINE="$(esc::sgr underline)"
  ESC_STDERR_ATTR_BLINK="$(esc::sgr blink)"
  ESC_STDERR_ATTR_FAST_BLINK="$(esc::sgr fast_blink)"
  ESC_STDERR_ATTR_REVERSE="$(esc::sgr reverse)"
  ESC_STDERR_ATTR_CONCEAL="$(esc::sgr conceal)"
  ESC_STDERR_ATTR_STRIKE="$(esc::sgr strike)"
  ESC_STDERR_ATTR_RESET_IE="$(esc::sgr reset_ie)"

  # color palette
  ESC_STDERR_FG_DEFAULT="$(esc::sgr 39)"
  ESC_STDERR_FG_GRAY="$(esc::sgr 103)"
  ESC_STDERR_FG_RED="$(esc::sgr  166)"
  ESC_STDERR_FG_RED="$(esc::sgr  167)"
  ESC_STDERR_FG_BLUE="$(esc::sgr 75)"
  ESC_STDERR_FG_YELLOW="$(esc::sgr 220)"
  ESC_STDERR_FG_CYAN="$(esc::sgr 195)"
  ESC_STDERR_FG_PINK="$(esc::sgr 175)"
  ESC_STDERR_FG_PURPLE="$(esc::sgr 105)"
  ESC_STDERR_FG_LIME="$(esc::sgr 155)"
  ESC_STDERR_FG_DARKGREEN="$(esc::sgr 36)"
else
  ESC_STDERR_RESET=

  # attributes
  ESC_STDERR_ATTR_RESET=
  ESC_STDERR_ATTR_BOLD=
  ESC_STDERR_ATTR_FAINT=
  ESC_STDERR_ATTR_ITALIC=
  ESC_STDERR_ATTR_UNDERLINE=
  ESC_STDERR_ATTR_BLINK=
  ESC_STDERR_ATTR_FAST_BLINK=
  ESC_STDERR_ATTR_REVERSE=
  ESC_STDERR_ATTR_CONCEAL=
  ESC_STDERR_ATTR_STRIKE=
  ESC_STDERR_ATTR_RESET_IE=

  # color palette
  ESC_STDERR_FG_DEFAULT=
  ESC_STDERR_FG_GRAY=
  ESC_STDERR_FG_RED=
  ESC_STDERR_FG_BLUE=
  ESC_STDERR_FG_YELLOW=
  ESC_STDERR_FG_CYAN=
  ESC_STDERR_FG_PINK=
  ESC_STDERR_FG_PURPLE=
  ESC_STDERR_FG_LIME=
  ESC_STDERR_FG_DARKGREEN=
fi

# shellcheck disable=SC2034
{
  ESC_TAG_BASE="$ESC_FG_CYAN"
  ESC_TAG_MAIN="$ESC_FG_PURPLE"
  ESC_TAG_ACCENT1="$ESC_FG_PINK"
  ESC_TAG_ACCENT2="$ESC_FG_LIME"
  ESC_TAG_STDERR_BASE="$ESC_FG_CYAN"
  ESC_TAG_STDERR_MAIN="$ESC_FG_PURPLE"
  ESC_TAG_STDERR_ACCENT1="$ESC_FG_PINK"
  ESC_TAG_STDERR_ACCENT2="$ESC_FG_LIME"
}
