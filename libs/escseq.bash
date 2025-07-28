#!/bin/bash

SCRIPTNAME='escseq.bash'
if [ -z "${BASH_VERSION:-}" ]; then
  echo "${SCRIPTNAME}: error: this library requires bash" >&2
  exit 1
fi

log_error() {
  local exitcode=1
  if [[ $1 =~ ^[0-9]+$ ]]; then
    exitcode=$1; shift
  fi
  printf '%s: line %s: %s: error: %s\n' \
    "$(basename "${BASH_SOURCE[1]}")" \
    "${BASH_LINENO[0]}" \
    "${FUNCNAME[1]:-main}" \
    "$*" >&2
  return $exitcode
}

if ! compgen -A function pt >/dev/null; then
  log_error 'pt.sh is not imported'
fi

ESCSEQ_ESC=''

escseq_sgr_help() {
    cat <<EOF
USAGE: sgr [option]...
DESCRIPTION:
    Print the ANSI escape code SGR(Select Graphic Rendition) parameter.
OPTIONS:
  - Reset:
      Omitting the option will reset the color and attributes.
  - Colors:
      black
      red
      green
      yellow
      blue
      magenta
      cyan
      white
      default
  - Attributes:
      reset_attr
      bold
      faint
      italic
      underline
      blink
      fast_blink
      reverse
      conceal
      strike
EOF
}

sgr() {
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
  local -r reset_all="${reset_attr};${default}"

  if [[ $# -eq 0 ]]; then
    pt "${ESCSEQ_ESC}[${reset_all}m"
    return 0
  fi

  local code_color
  local code_attr_arr=()
  while (( $# > 0 )); do
    case "$1" in
      # colors
      black)    code_color="$black";;
      red)      code_color="$red";;
      green)    code_color="$green";;
      yellow)   code_color="$yellow";;
      blue)     code_color="$blue";;
      magenta)  code_color="$magenta";;
      cyan)     code_color="$cyan";;
      white)    code_color="$white";;
      default)  code_color="$default";;
      [0-9]*)   code_color="38;5;$1";;
      # attributes
      reset_attr)  code_attr_arr+=("$reset_attr");;
      bold)        code_attr_arr+=("$bold");;
      italic)      code_attr_arr+=("$italic");;
      underline)   code_attr_arr+=("$underline");;
      blink)       code_attr_arr+=("$blink");;
      # others
      -h | --help) escseq_sgr_help; return 0;;
      *) log_error "illegal option: $1";;
    esac
    shift
  done

  local -r code_attr_arr_len="${#code_attr_arr[@]}"
  if [[ $code_attr_arr_len -eq 0 ]]; then
    if [[ -z ${code_color:-} ]]; then
      log_error 'code_color is empty'
    else
      pt "${ESCSEQ_ESC}[${code_color}m"
    fi
  else
    local -r code_attr=$(for attr in "${code_attr_arr[@]}"; do pt "${attr};"; done)
    if [[ -z ${code_color:-} ]]; then
      pt "${ESCSEQ_ESC}[${code_attr%;}m"
    else
      pt "${ESCSEQ_ESC}[${code_attr}${code_color}m"
    fi
  fi
}
