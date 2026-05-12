# shellcheck shell=bash

LIB_VERSION='1.0.0'
LIB_DEPS=()
[[ "${1:-}" = '__IMPORT__' ]] && return 0

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
  local -r bright_black='90'
  local -r bright_red='91'
  local -r bright_green='92'
  local -r bright_yellow='93'
  local -r bright_blue='94'
  local -r bright_magenta='95'
  local -r bright_cyan='96'
  local -r bright_white='97'

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
      default)  code_color="$default" ;;
      black)    code_color="$black" ;;
      red)      code_color="$red" ;;
      green)    code_color="$green" ;;
      yellow)   code_color="$yellow" ;;
      blue)     code_color="$blue" ;;
      magenta)  code_color="$magenta" ;;
      cyan)     code_color="$cyan" ;;
      white)    code_color="$white" ;;
      bright_black)    code_color="$bright_black" ;;
      bright_red)      code_color="$bright_red" ;;
      bright_green)    code_color="$bright_green" ;;
      bright_yellow)   code_color="$bright_yellow" ;;
      bright_blue)     code_color="$bright_blue" ;;
      bright_magenta)  code_color="$bright_magenta" ;;
      bright_cyan)     code_color="$bright_cyan" ;;
      bright_white)    code_color="$bright_white" ;;
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

esc::sgr_list_colors() {
  local reset bold faint
  local name value
  reset="$(printf '\033[0m')"
  bold="$(printf '\033[1m')"
  faint="$(printf '\033[2m')"
  printf '%b%-27s%-27s%s%b\n' "$bold" 'DEFAULT' 'BOLD' 'FAINT' "$reset"
  while IFS= read -r name; do
    value="${!name-}"
    [[ -z "$value" ]] && continue
    printf '%b%-27s%b%-27s%b%s%b\n' \
      "$value" "$name" \
      "$bold" "$name" \
      "$faint" "$name" \
      "$reset"
  done < <(compgen -v 'ESC_C')
}

# shellcheck disable=SC2034
esc::sgr_base() {

  # ------------------
  #     attributes
  # ------------------

  if esc::_colors_supported; then
    ESC_RESET="$(esc::sgr)"
    ESC_DEFAULT="$(esc::sgr default)"
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
  else
    ESC_RESET=
    ESC_DEFAULT=
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
  fi

  # attributes (stderr)
  if esc::_colors_supported_stderr; then
    ESC_STDERR_RESET="$(esc::sgr)"
    ESC_STDERR_DEFAULT="$(esc::sgr default)"
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
  else
    ESC_STDERR_RESET=
    ESC_STDERR_DEFAULT=
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
  fi

  # ---------------------------
  #     4-bit color pallets
  # ---------------------------

  if esc::_colors_supported; then
    # normal colors
    ESC_ANSI_BLACK="$(esc::sgr black)"
    ESC_ANSI_RED="$(esc::sgr red)"
    ESC_ANSI_GREEN="$(esc::sgr green)"
    ESC_ANSI_YELLOW="$(esc::sgr yellow)"
    ESC_ANSI_BLUE="$(esc::sgr blue)"
    ESC_ANSI_MAGENTA="$(esc::sgr magenta)"
    ESC_ANSI_CYAN="$(esc::sgr cyan)"
    ESC_ANSI_WHITE="$(esc::sgr white)"
    # bright colors
    ESC_ANSI_BRIGHT_BLACK="$(esc::sgr bright_black)"
    ESC_ANSI_BRIGHT_RED="$(esc::sgr bright_red)"
    ESC_ANSI_BRIGHT_GREEN="$(esc::sgr bright_green)"
    ESC_ANSI_BRIGHT_YELLOW="$(esc::sgr bright_yellow)"
    ESC_ANSI_BRIGHT_BLUE="$(esc::sgr bright_blue)"
    ESC_ANSI_BRIGHT_MAGENTA="$(esc::sgr bright_magenta)"
    ESC_ANSI_BRIGHT_CYAN="$(esc::sgr bright_cyan)"
    ESC_ANSI_BRIGHT_WHITE="$(esc::sgr bright_white)"
  else
    # normal colors
    ESC_ANSI_BLACK=
    ESC_ANSI_RED=
    ESC_ANSI_GREEN=
    ESC_ANSI_YELLOW=
    ESC_ANSI_BLUE=
    ESC_ANSI_MAGENTA=
    ESC_ANSI_CYAN=
    ESC_ANSI_WHITE=
    # bright colors
    ESC_ANSI_BRIGHT_BLACK=
    ESC_ANSI_BRIGHT_RED=
    ESC_ANSI_BRIGHT_GREEN=
    ESC_ANSI_BRIGHT_YELLOW=
    ESC_ANSI_BRIGHT_BLUE=
    ESC_ANSI_BRIGHT_MAGENTA=
    ESC_ANSI_BRIGHT_CYAN=
    ESC_ANSI_BRIGHT_WHITE=
  fi

  if esc::_colors_supported_stderr; then
    # standard colors
    ESC_STDERR_ANSI_BLACK="$(esc::sgr black)"
    ESC_STDERR_ANSI_RED="$(esc::sgr red)"
    ESC_STDERR_ANSI_GREEN="$(esc::sgr green)"
    ESC_STDERR_ANSI_YELLOW="$(esc::sgr yellow)"
    ESC_STDERR_ANSI_BLUE="$(esc::sgr blue)"
    ESC_STDERR_ANSI_MAGENTA="$(esc::sgr magenta)"
    ESC_STDERR_ANSI_CYAN="$(esc::sgr cyan)"
    ESC_STDERR_ANSI_WHITE="$(esc::sgr white)"
    # bright colors
    ESC_STDERR_ANSI_BRIGHT_BLACK="$(esc::sgr bright_black)"
    ESC_STDERR_ANSI_BRIGHT_RED="$(esc::sgr bright_red)"
    ESC_STDERR_ANSI_BRIGHT_GREEN="$(esc::sgr bright_green)"
    ESC_STDERR_ANSI_BRIGHT_YELLOW="$(esc::sgr bright_yellow)"
    ESC_STDERR_ANSI_BRIGHT_BLUE="$(esc::sgr bright_blue)"
    ESC_STDERR_ANSI_BRIGHT_MAGENTA="$(esc::sgr bright_magenta)"
    ESC_STDERR_ANSI_BRIGHT_CYAN="$(esc::sgr bright_cyan)"
    ESC_STDERR_ANSI_BRIGHT_WHITE="$(esc::sgr bright_white)"
  else
    # standard colors (stderr)
    ESC_STDERR_ANSI_BLACK=
    ESC_STDERR_ANSI_RED=
    ESC_STDERR_ANSI_GREEN=
    ESC_STDERR_ANSI_YELLOW=
    ESC_STDERR_ANSI_BLUE=
    ESC_STDERR_ANSI_MAGENTA=
    ESC_STDERR_ANSI_CYAN=
    ESC_STDERR_ANSI_WHITE=
    # bright colors (stderr)
    ESC_STDERR_ANSI_BRIGHT_BLACK=
    ESC_STDERR_ANSI_BRIGHT_RED=
    ESC_STDERR_ANSI_BRIGHT_GREEN=
    ESC_STDERR_ANSI_BRIGHT_YELLOW=
    ESC_STDERR_ANSI_BRIGHT_BLUE=
    ESC_STDERR_ANSI_BRIGHT_MAGENTA=
    ESC_STDERR_ANSI_BRIGHT_CYAN=
    ESC_STDERR_ANSI_BRIGHT_WHITE=
  fi

  # ---------------------
  #     color pallets
  # ---------------------

  # 以下の変数を上書きすることでカラースキームを構成します。
  # 色を追加する場合、本関数にも随時追加してください。

  ESC_GRAY=
  ESC_RED=
  ESC_SCARLET=
  ESC_GREEN=
  ESC_LIME=
  ESC_YELLOW=
  ESC_BLUE=
  ESC_PURPLE=
  ESC_PINK=
  ESC_CYAN=
  ESC_BRIGHT_CYAN=
  ESC_DARK_GREEN=

  ESC_STDERR_GRAY=
  ESC_STDERR_RED=
  ESC_STDERR_SCARLET=
  ESC_STDERR_GREEN=
  ESC_STDERR_LIME=
  ESC_STDERR_YELLOW=
  ESC_STDERR_BLUE=
  ESC_STDERR_PURPLE=
  ESC_STDERR_PINK=
  ESC_STDERR_CYAN=
  ESC_STDERR_BRIGHT_CYAN=
  ESC_STDERR_DARK_GREEN=

  # color templates
  # base, main, accent
  ESC_C_BASE=
  ESC_C_MAIN=
  ESC_C_ACCENT1=
  # base, main, accent (stderr)
  ESC_C_STDERR_BASE=
  ESC_C_STDERR_MAIN=
  ESC_C_STDERR_ACCENT1=
  # severity
  ESC_C_PANIC=
  ESC_C_CRITICAL=
  ESC_C_WARNING=
  ESC_C_NOTICE=
  ESC_C_INFO=
  ESC_C_DEBUG=
  # severity (stderr)
  ESC_C_STDERR_PANIC=
  ESC_C_STDERR_CRITICAL=
  ESC_C_STDERR_WARNING=
  ESC_C_STDERR_NOTICE=
  ESC_C_STDERR_INFO=
  ESC_C_STDERR_DEBUG=
  # result
  ESC_C_COMPLETE=
  ESC_C_SUCCESS=
  ESC_C_FAILURE=
  ESC_C_GRAYOUT=
  ESC_C_DANGER=
  # result (stderr)
  ESC_C_STDERR_COMPLETE=
  ESC_C_STDERR_SUCCESS=
  ESC_C_STDERR_FAILURE=
  ESC_C_STDERR_GRAYOUT=
  ESC_C_STDERR_DANGER=
}

# --------------------
#     color schemes
# --------------------

# shellcheck disable=SC2034
esc::scheme_rebecca() {
  if esc::_colors_supported; then
    ESC_GRAY="$(esc::sgr 103)"
    ESC_RED="$(esc::sgr  167)"
    ESC_SCARLET="$(esc::sgr 196)"
    ESC_GREEN="$(esc::sgr 43)"
    ESC_LIME="$(esc::sgr 155)"
    ESC_YELLOW="$(esc::sgr 220)"
    ESC_BLUE="$(esc::sgr 75)"
    ESC_PURPLE="$(esc::sgr 105)"
    ESC_PINK="$(esc::sgr 175)"
    ESC_CYAN="$(esc::sgr 122)"
    ESC_BRIGHT_CYAN="$(esc::sgr 195)"
    ESC_DARK_GREEN="$(esc::sgr 30)"
  fi

  if esc::_colors_supported_stderr; then
    ESC_STDERR_GRAY="$(esc::sgr 103)"
    ESC_STDERR_RED="$(esc::sgr  167)"
    ESC_STDERR_SCARLET="$(esc::sgr 196)"
    ESC_STDERR_GREEN="$(esc::sgr 43)"
    ESC_STDERR_LIME="$(esc::sgr 155)"
    ESC_STDERR_YELLOW="$(esc::sgr 220)"
    ESC_STDERR_BLUE="$(esc::sgr 75)"
    ESC_STDERR_PURPLE="$(esc::sgr 105)"
    ESC_STDERR_PINK="$(esc::sgr 175)"
    ESC_STDERR_CYAN="$(esc::sgr 122)"
    ESC_STDERR_BRIGHT_CYAN="$(esc::sgr 195)"
    ESC_STDERR_DARK_GREEN="$(esc::sgr 30)"
  fi

  # color templates
  # base, main, accent
  ESC_C_BASE="$ESC_BRIGHT_CYAN"
  ESC_C_MAIN="$ESC_PURPLE"
  ESC_C_ACCENT1="$ESC_LIME"
  # base, main, accent (stderr)
  ESC_C_STDERR_BASE="$ESC_STDERR_BRIGHT_CYAN"
  ESC_C_STDERR_MAIN="$ESC_STDERR_PURPLE"
  ESC_C_STDERR_ACCENT1="$ESC_STDERR_LIME"
  # severity
  ESC_C_PANIC="$ESC_SCARLET"
  ESC_C_CRITICAL="$ESC_RED"
  ESC_C_WARNING="$ESC_YELLOW"
  ESC_C_NOTICE="$ESC_CYAN"
  ESC_C_INFO="$ESC_BLUE"
  ESC_C_DEBUG="$ESC_DARK_GREEN"
  # severity (stderr)
  ESC_C_STDERR_PANIC="$ESC_STDERR_SCARLET"
  ESC_C_STDERR_CRITICAL="$ESC_STDERR_RED"
  ESC_C_STDERR_WARNING="$ESC_STDERR_YELLOW"
  ESC_C_STDERR_NOTICE="$ESC_STDERR_CYAN"
  ESC_C_STDERR_INFO="$ESC_STDERR_BLUE"
  ESC_C_STDERR_DEBUG="$ESC_STDERR_DARK_GREEN"
  # result
  ESC_C_COMPLETE="$ESC_PINK"
  ESC_C_SUCCESS="$ESC_BLUE"
  ESC_C_FAILURE="$ESC_RED"
  ESC_C_GRAYOUT="$ESC_GRAY"
  ESC_C_DANGER="$ESC_RED"
  # result (stderr)
  ESC_C_STDERR_COMPLETE="$ESC_STDERR_PINK"
  ESC_C_STDERR_SUCCESS="$ESC_STDERR_BLUE"
  ESC_C_STDERR_FAILURE="$ESC_STDERR_RED"
  ESC_C_STDERR_GRAYOUT="$ESC_STDERR_GRAY"
  ESC_C_STDERR_DANGER="$ESC_STDERR_RED"
}

esc::sgr_base
esc::scheme_rebecca
