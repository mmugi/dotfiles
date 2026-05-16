# shellcheck shell=bash

LIB_VERSION='1.0.0'
LIB_DEPS=( core escseq termcap )
[[ "${1:-}" = '__IMPORT__' ]] && return 0

# Bash Theme Loader <theme.sh>
#
# * Usage *
#
#   # テーマの読み込み
#   theme::load <theme>
#
#   # テーマのリセット
#   theme::clear
#
# * Description *
#
#   `themes/<theme>.sh` もしくは `themes/<theme>/init.sh` をsourceして `<theme>::setup()` を実行します。
#
#   themeには、`<theme>::setup()` が定義される必要があります( `Theme Requirements` を参照)。
#   setupが実行されると、palette mapとpalette mapをもとに構成されるstyle mapが定義されます。
#
#   `theme::load` では、setupで定義されたstyle mapを元にして、`THEME_STYLE_MAP_NAME_STDOUT` ,
#   `THEME_STYLE_MAP_NAME_STDERR` に示す名前の連想配列を生成します。
#   この配列は、スタイルを適用したい場面にあわせて利用してください。
#   キーの構成はテーマによって定義されるため、キーが空になる場合があります。
#   そのため、利用側でfallbackを行うようにしてください。
#
#   `THEME_STYLE_MAP_NAME_STDOUT`、`THEME_STYLE_MAP_NAME_STDERR` はそれぞれ、標準出力・標準エラー出力用
#   に定義されます。`theme::load` 実行時に、標準出力(fd 1)、標準エラー出力(fd 2)がターミナルに
#   接続されているかどうかを判定し、接続されていない場合はそれぞれの配列を空にセットします。
#
#   `TERMCAP_COLOR_MODE` で上記の動作をオーバーライド可能です。(termcap.sh参照)
#     - auto: fdのターミナル接続をチェック (default)
#     - always: 常にエスケープシーケンスを定義
#     - never: 常に空で定義 (NO_COLORを定義しても同じ動作になります)
#
#   `theme::clear` で適用したテーマ(定義した配列)を初期化します。
#   `theme::clear` は、`theme::load` を実行時にも呼ばれ、配列を初期化したのち
#   テーマが再適用されます。
#
#   `THEME_STYLE_COMMON` に定義されたstyleはどのテーマも共通して適用されます。
#   作成したテーマのstyle mapに `THEME_STYLE_COMMON` と重複するキーが含まれる場合、エラーとともに
#   status 1 でテーマの適用を中止します。テーマのキーを重複しない値に変更してください。
#   また、テーマ内で重複するキーがある場合は、あとに定義しているものが優先されます。
#
# * Theme Requirements *
#
#   1. themeファイルは以下のどちらかの形式をとる。
#     - `themes/<theme名>.sh`
#     - `themes/<theme名>/init.sh`
#       - `themes/<theme名>.sh` の形式が取れない場合は、`themes/<theme名>/init.sh` の形式を利用し、
#         関連ファイルを、`themes/<theme名>/` 配下に配置する。
#
#   2. themeファイルに `<theme名>::setup()` 関数が定義されている。
#
#   3. setupの実行で、以下2つの連想配列をグローバルに定義される。
#
#     THEME_PALETTE_MAP_NAME と同名の連想配列:
#       - 使用するカラーコード一覧を定義(RGB形式でも指定可(区切り文字: `:` or `;`))
#       - 例:
#            declare -g -A THEME_PALETTE=(
#              ['white']='#000000'
#              ['red']='#ff0000'
#              ['blue']='0;0;255'
#              ['yellow']='255:255:0'
#              ...
#            )
#
#     THEME_STYLE_MAP_NAME と同名の連想配列:
#       - エスケープシーケンスを定義
#       - 標準のテーマではエスケープシーケンスの出力に escseq.sh を利用
#       - 例:
#            declare -g -A THEME_STYLE=(
#              ['error']="$(escseq::sgr --fg-tc "${THEME_PALETTE['red']}")"
#              ['info']="$(escseq::sgr --fg-tc "${THEME_PALETTE['blue']}")"
#              ...
#            )
#

if [[ "${_IMPORT_INITIALIZED:-false}" == 'true' ]]; then
  return 0
else
  _IMPORT_INITIALIZED=true
fi

readonly THEME_DEFAULT='mmerr'
readonly THEME_PALETTE_MAP_NAME='THEME_PALETTE'
readonly THEME_STYLE_MAP_NAME='THEME_STYLE'
readonly THEME_STYLE_MAP_NAME_STDOUT='STYLE_STDOUT'
readonly THEME_STYLE_MAP_NAME_STDERR='STYLE_STDERR'

declare -gA "${THEME_PALETTE_MAP_NAME}=()"
declare -gA "${THEME_STYLE_MAP_NAME}=()"
declare -gA "${THEME_STYLE_MAP_NAME_STDOUT}=()"
declare -gA "${THEME_STYLE_MAP_NAME_STDERR}=()"

declare -g -rA THEME_STYLE_COMMON=(
  ['rst']="$(escseq::sgr --reset)"
  ['bold']="$(escseq::sgr --bold)"
  ['faint']="$(escseq::sgr --faint)"
  ['italic']="$(escseq::sgr --italic)"
  ['underline']="$(escseq::sgr --underline)"
  ['blink']="$(escseq::sgr --blink)"
  ['rapid_blink']="$(escseq::sgr --rapid_blink)"
  ['reverse']="$(escseq::sgr --reverse)"
  ['conceal']="$(escseq::sgr --conceal)"
  ['strike']="$(escseq::sgr --strike)"
  ['default_intensity']="$(escseq::sgr --default-intensity)"
)

theme::_check_duplicate_map_key() {
  local -n map1="$1"
  local -n map2="$2"
  local key duplicated=0

  for key in "${!map1[@]}"; do
    if [[ -v "map2[${key}]" ]]; then
      core::error "duplicate map key: ${key}"
      duplicated=1
    fi
  done

  return "$duplicated"
}

theme::_apply_styles() {
  local fd="$1" init_map_name key

  case "$fd" in
    1) init_map_name="$THEME_STYLE_MAP_NAME_STDOUT" ;;
    2) init_map_name="$THEME_STYLE_MAP_NAME_STDERR" ;;
    *)
      core::error "invalid fd: ${fd}"
      return 1
      ;;
  esac

  local -n style_map="$THEME_STYLE_MAP_NAME"
  local -n init_map="$init_map_name"

  if ! theme::_check_duplicate_map_key 'THEME_STYLE_COMMON' "$THEME_STYLE_MAP_NAME"; then
    theme::clear
    return 1
  fi

  if termcap::is_color_supported "$fd"; then
    for key in "${!THEME_STYLE_COMMON[@]}"; do
      init_map["$key"]="${THEME_STYLE_COMMON["$key"]}"
    done
    for key in "${!style_map[@]}"; do
      init_map["$key"]="${style_map["$key"]}"
    done
  else
    # shellcheck disable=SC2034
    declare -g -A init_map=()
  fi
}

theme::clear() {
  declare -g -A "${THEME_PALETTE_MAP_NAME}=()"
  declare -g -A "${THEME_STYLE_MAP_NAME}=()"
  declare -g -A "${THEME_STYLE_MAP_NAME_STDOUT}=()"
  declare -g -A "${THEME_STYLE_MAP_NAME_STDERR}=()"
}

theme::load() {
  local script_dir
  script_dir="$(dirname "$(realpath -- "${BASH_SOURCE[0]}")")"

  if (( $# > 1 )); then
    core::error "illegal options: $*"
    return 1
  fi

  local theme="${1:-"$THEME_DEFAULT"}"
  local theme_dir="${script_dir}/themes"
  local theme_file

  if [[ -f "${theme_dir}/${theme}.sh" ]]; then
    theme_file="${theme_dir}/${theme}.sh"
  elif [[ -f "${theme_dir}/${theme}/init.sh" ]]; then
    theme_file="${theme_dir}/${theme}/init.sh"
  else
    core::error "cannot find theme: ${theme}"
    return 1
  fi

  theme::clear

  # shellcheck source=/dev/null
  source "$theme_file"
  if ! "${theme}::setup"; then
    core::error 'setup failed'
    return 1
  fi

  theme::_apply_styles 1
  theme::_apply_styles 2
}

theme::list_styles() {
  local reset bold key
  local count=0
  local -n style_map="$THEME_STYLE_MAP_NAME"
  local -n style_map_stdout="$THEME_STYLE_MAP_NAME_STDOUT"
  local -n style_map_stderr="$THEME_STYLE_MAP_NAME_STDERR"

  local orig=true all=false stdout=false stderr=false
  while (( $# > 0 )); do
    case "$1" in
      --all)    all=true ;;
      --stdout) orig=false; stdout=true ;;
      --stderr) orig=false; stderr=true ;;
      *)
        core::error "illegal option: $1"
        return 1
    esac
    shift
  done

  reset="$(printf '\033[0m')"
  bold="$(printf '\033[1m')"

  if [[ "$all" == 'true' || "$orig" == 'true' ]]; then
    printf '%b< %s >%b\n' "$bold" "$THEME_STYLE_MAP_NAME" "$reset"
    for key in "${!style_map[@]}"; do
      printf '%-25s %b%s%b\n' "$key" "${style_map["$key"]}" 'TEST MESSAGE' "$reset"
      count=$(( count+1 ))
    done
    printf "%b< %s styles listed >%b\n" "$bold" "$count" "$reset"
    count=0
  fi

  if [[ "$all" == 'true' || "$stdout" == 'true' ]]; then
    printf '%b< %s >%b\n' "$bold" "$THEME_STYLE_MAP_NAME_STDOUT" "$reset"
    for key in "${!style_map_stdout[@]}"; do
      printf '%-25s %b%s%b\n' "$key" "${style_map_stdout["$key"]}" 'TEST MESSAGE' "$reset"
      count=$(( count+1 ))
    done
    printf "%b< %s styles listed >%b\n" "$bold" "$count" "$reset"
    count=0
  fi

  if [[ "$all" == 'true' || "$stdout" == 'true' ]]; then
    printf '%b< %s >%b\n' "$bold" "$THEME_STYLE_MAP_NAME_STDERR" "$reset"
    for key in "${!style_map_stderr[@]}"; do
      printf '%-25s %b%s%b\n' "$key" "${style_map_stderr["$key"]}" 'TEST MESSAGE' "$reset"
      count=$(( count+1 ))
    done
    printf "%b< %s styles listed >%b\n" "$bold" "$count" "$reset"
    count=0
  fi
}
