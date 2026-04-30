# shellcheck shell=bash
# shellcheck disable=SC2034
LIB_DEPS=( core escseq termcap )
[[ "${1:-}" = '__META_PROBE__' ]] && return 0

# USAGE:
#   theme::loader <themefile>
#
# DESCRIPTION:
#   - themes/<theme_name>.sh をsourceする。
#   - THEME_PALETTE に定義されるテーマ変数を themefile で定義する。
#   - THEME_PALETTE の変数が定義されていない場合は読み込みエラーを確認して、
#     themefile の変数を確認する。
#   - テーマ変数には指定のカラーのエスケープシーケンス出力を定義する。
#   - 読み込んだテーマ変数から以下のサフィックスを付与したstdout, stderr用の
#     変数を定義する。
#     - THEME_VAR_STDOUT_SUFFIX: _STDOUT
#     - THEME_VAR_STDERR_SUFFIX: _STDERR
#   - fd 1(stdout), 2(stderr)がターミナルに接続されているかどうかをチェックし、
#     接続されていない場合はそれぞれの変数を空にセットする。
#   - TERMCAP_COLOR_MODE で上記の動作をオーバーライド可能。(termcap.sh参照)
#     - auto: fdのターミナル接続をチェック
#     - always: 常にエスケープシーケンスを定義
#     - never: 常に空で定義 (NO_COLORを定義した場合と同じ動作)

readonly THEME_VAR_STDOUT_SUFFIX='_STDOUT'
readonly THEME_VAR_STDERR_SUFFIX='_STDERR'
readonly THEME_PALETTE=(
  THEME_RESET
  THEME_BOLD
  THEME_FAINT
  THEME_ITALIC
  THEME_UNDERLINE
  THEME_BLINK
  THEME_RAPID_BLINK
  THEME_REVERSE
  THEME_CONCEAL
  THEME_STRIKE
  THEME_DEFAULT_INTENCITY

  THEME_COLOR_BASE
  THEME_COLOR_MAIN
  THEME_COLOR_SUB
  THEME_COLOR_ACCENT
  THEME_COLOR_MUTED

  THEME_COLOR_FATAL
  THEME_COLOR_ERROR
  THEME_COLOR_WARN
  THEME_COLOR_NOTICE
  THEME_COLOR_INFO
  THEME_COLOR_DEBUG

  THEME_COLOR_SUCCESS
  THEME_COLOR_FAILURE

  THEME_COLOR_HEALTHY
  THEME_COLOR_UNHEALTHY

  THEME_COLOR_COMPLETE
  THEME_COLOR_DANGER
)

THEME_RESET="$(escseq::sgr reset)"
THEME_BOLD="$(escseq::sgr bold)"
THEME_FAINT="$(escseq::sgr faint)"
THEME_ITALIC="$(escseq::sgr italic)"
THEME_UNDERLINE="$(escseq::sgr underline)"
THEME_BLINK="$(escseq::sgr blink)"
THEME_RAPID_BLINK="$(escseq::sgr rapid_blink)"
THEME_REVERSE="$(escseq::sgr reverse)"
THEME_CONCEAL="$(escseq::sgr conceal)"
THEME_STRIKE="$(escseq::sgr strike)"
THEME_DEFAULT_INTENCITY="$(escseq::sgr default_intencity)"

theme::_verificate() {
  local missing=false
  local missing_vars=()
  local var_stderr

  for var in "${THEME_PALETTE[@]}"; do
    if [[ ! -v "$var" ]]; then
      missing=true
      missing_vars+=( "$var" )
    fi
  done

  if [[ "$missing" == 'true' ]]; then
    core::error "required theme variable not set:" "${missing_vars[@]}"
    return 1
  fi

  return 0
}

theme::_apply_theme_stdout() {
  local varname
  if termcap::is_color_supported 1; then
    for theme_var in "${THEME_PALETTE[@]}"; do
      varname="${theme_var}${THEME_VAR_STDOUT_SUFFIX}"
      printf -v "$varname" '%s' "${!theme_var}"
    done
  else
    for theme_var in "${THEME_PALETTE[@]}"; do
      varname="${theme_var}${THEME_VAR_STDOUT_SUFFIX}"
      printf -v "$varname" '%s' ''
    done
  fi
}

theme::_apply_theme_stderr() {
  local varname
  if termcap::is_color_supported 2; then
    for theme_var in "${THEME_PALETTE[@]}"; do
      varname="${theme_var}${THEME_VAR_STDERR_SUFFIX}"
      printf -v "$varname" '%s' "${!theme_var}"
    done
  else
    for theme_var in "${THEME_PALETTE[@]}"; do
      varname="${theme_var}${THEME_VAR_STDERR_SUFFIX}"
      printf -v "$varname" '%s' ''
    done
  fi
}

theme::_apply_theme() {
  local fd="${1:-1}"
  case "$fd" in
    1) theme::_apply_theme_stdout ;;
    2) theme::_apply_theme_stderr ;;
    *)
      core::error "invalid fd: ${fd}"
      return 1
      ;;
  esac
}

theme::load() {
  local script_dir
  script_dir="$(dirname "$(realpath -- "${BASH_SOURCE[0]}")")"

  if (( $# == 0 )); then
    core::error "missing themefile operand: ${theme_file}"
    return 1
  elif (( $# > 1 )); then
    core::error "illegal options: $*"
    return 1
  fi

  local theme_name="$1"
  local theme_file="${script_dir:?}/themes/${theme_name}.sh"

  if [[ ! -f "$theme_file" ]]; then
    core::error "theme file not found: ${theme_file}"
    return 1
  fi

  # shellcheck source=/dev/null
  source "$theme_file"
  if theme::_verificate; then
    theme::_apply_theme 1
    theme::_apply_theme 2
  else
    core::error "theme file verification failed: ${theme_file}"
    exit 1
  fi
}

theme::list_colors() {
  local reset bold faint
  local name value

  reset="$(printf '\033[0m')"
  bold="$(printf '\033[1m')"
  faint="$(printf '\033[2m')"

  printf '%b%-27s%-27s%s%b\n' \
    "$bold" 'DEFAULT' 'BOLD' 'FAINT' "$reset"
  while IFS= read -r name; do
    value="${!name-}"
    [[ -z "$value" ]] && continue
    printf '%b%-27s%b%-27s%b%s%b\n' \
      "$value" "$name" \
      "$bold" "$name" \
      "$faint" "$name" \
      "$reset"
  done < <(compgen -A variable 'THEME_COLOR_' \
             | grep -v -e "$THEME_VAR_STDOUT_SUFFIX" \
                       -e "$THEME_VAR_STDERR_SUFFIX")
}
