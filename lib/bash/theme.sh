# shellcheck shell=bash

# @deps core escseq termcap

# Bash Theme Loader <theme.sh>
#
# * Usage *
#
#   # テーマの読み込み
#   theme::load <theme>
#
# * Description *
#
#   `themes/<theme>.sh` をsourceして `<theme>::setup()` を実行します。
#
#   themeには、`<theme>::setup()` が定義される必要があります( `Theme Requirements` を参照)。
#   setupが実行されると、連想配列 `THEME_PALETTE`、`THEME_STYLE` が
#   定義されます。
#
#   `theme::load` では、`THEME_STYLE` を元に、標準出力用の連想配列 `STYLE` と
#   標準エラー出力用の `STYLE_ERR` を生成します。どちらも同じキーを持ち、キーは
#   スタイル名、値はスタイルのエスケープシーケンスを持ちます。`theme::load` 実行時に
#   標準出力(fd 1)、標準エラー出力(fd 2)がターミナルに接続されているかどうか判定され、
#   接続されていない場合は値を空文字にします。
#
#   `TERMCAP_COLOR_MODE` で上記の動作をオーバーライド可能です。(termcap.sh参照)
#     - auto   : fdのターミナル接続をチェック (default)
#     - always : 常にエスケープシーケンスを定義
#     - never  : 常に空で定義 (NO_COLORを定義しても同じ動作になります)
#
#   `THEME_STYLE_COMMON` に定義されたスタイルはどのテーマも共通して適用されます。
#   作成したテーマの `THEME_STYLE` に `THEME_STYLE_COMMON` と重複するキーが含まれる
#   場合、エラーとともに status 1 でテーマの適用を中止します。テーマのキーを重複
#   しない値に変更してください。
#
#   また、テーマ内で重複するキーがある場合は、あとに定義しているものが優先されます。
#
# * Theme Requirements *
#
#   1. themeファイルが `themes/<theme名>.sh` に配置されている。
#
#   2. themeファイルに `<theme名>::setup()` 関数が定義されている。
#
#   3. `<theme名>::setup` 実行で、以下2つの連想配列がグローバルに定義される。
#
#     THEME_PALETTE:
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
#     THEME_STYLE:
#       - エスケープシーケンスを定義
#       - 標準のテーマではエスケープシーケンスの出力に escseq.sh を利用
#       - 例:
#            declare -g -A THEME_STYLE=(
#              ['error']="$(escseq::sgr --fg-tc "${THEME_PALETTE['red']}")"
#              ['info']="$(escseq::sgr --fg-tc "${THEME_PALETTE['blue']}")"
#              ...
#            )

declare -gr THEME_DEFAULT='mmerr'
declare -grA THEME_STYLE_COMMON=(
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
  ['noitalic']="$(escseq::sgr --noitalic)"
  ['nounderline']="$(escseq::sgr --nounderline)"
  ['noblink']="$(escseq::sgr --noblink)"
  ['noreverse']="$(escseq::sgr --noreverse)"
  ['reveal']="$(escseq::sgr --reveal)"
  ['nostrike']="$(escseq::sgr --nostrike)"
  ['default_fg']="$(escseq::sgr --default-fg)"
  ['default_bg']="$(escseq::sgr --default-bg)"
)

# 連想配列として宣言し直す。未宣言の名前へ nameref 経由で代入すると添字配列に
# なり文字列キーが使えないため、theme::_apply_styles のための型の用意も兼ねる。
#
# いずれもライブラリの外から参照されるグローバル連想配列。
# shellcheck disable=SC2034
theme::_clear() {
  declare -g -A THEME_PALETTE=()
  declare -g -A THEME_STYLE=()
  declare -g -A STYLE=()
  declare -g -A STYLE_ERR=()
}

theme::_check_duplicate_keys() {
  local key duplicated=0

  for key in "${!THEME_STYLE_COMMON[@]}"; do
    if [[ -v "THEME_STYLE[${key}]" ]]; then
      core::error "duplicate map key: ${key}"
      duplicated=1
    fi
  done

  return "$duplicated"
}

# init_map は nameref なので、代入先は参照先のグローバル配列になる。
# shellcheck disable=SC2034
theme::_apply_styles() {
  local fd="$1" init_map_name key

  case "$fd" in
    1) init_map_name='STYLE' ;;
    2) init_map_name='STYLE_ERR' ;;
    *)
      core::error "invalid fd: ${fd}"
      return 1
      ;;
  esac

  local -n init_map="$init_map_name"

  # 色が使えない場合キーは用意し、値だけ空にする。
  local colored=''
  termcap::is_color_supported "$fd" && colored=1

  # nameref に対して declare を使うと参照先ではなく `init_map` という名前の
  # 変数が新規に作られてしまうため、nameref 経由の通常代入でクリアする。
  init_map=()

  for key in "${!THEME_STYLE_COMMON[@]}"; do
    init_map["$key"]="${colored:+${THEME_STYLE_COMMON["$key"]}}"
  done
  for key in "${!THEME_STYLE[@]}"; do
    init_map["$key"]="${colored:+${THEME_STYLE["$key"]}}"
  done
}

theme::load() {
  local script_dir
  script_dir="$(dirname "$(realpath -- "${BASH_SOURCE[0]}")")"

  if (( $# > 1 )); then
    core::error "illegal options: $*"
    return 1
  fi

  local theme="${1:-"$THEME_DEFAULT"}"
  local theme_file="${script_dir}/themes/${theme}.sh"

  if [[ ! -f "$theme_file" ]]; then
    core::error "theme file not found: ${theme_file}"
    return 1
  fi

  theme::_clear

  # shellcheck source=/dev/null
  if ! source "$theme_file"; then
    core::error "failed to source theme file: ${theme_file}"
    theme::_clear
    return 1
  fi

  if ! "${theme}::setup"; then
    core::error 'setup failed'
    theme::_clear
    return 1
  fi

  # fdごとではなくテーマ単位のチェックなので、_apply_styles ではなくここで
  # 1度だけ行う。_apply_styles 内で行うと同じエラーが2度出ていた。
  if ! theme::_check_duplicate_keys; then
    theme::_clear
    return 1
  fi

  theme::_apply_styles 1
  theme::_apply_styles 2
}
