# shellcheck shell=bash

# Bash Library Loader <import.sh>
#
# * Usage *
#
#   source path/to/import.sh
#   import <library名> ...
#
# * Library Import *
#
#   import.sh読み込み後、`import()` の引数に読み込むライブラリ名を指定して実行します。
#   検索パス(後述)から `<library名>.sh` を検索しsourceします。
#
#   `import()` で読み込まれたライブラリは `IMPORT_IMPORTED_LIBS` 連想配列にセット
#   されます(key: <library名>, value: 読み込んだファイルパス)。
#
#   この連想配列は、ライブラリの再読み込みなどを防ぐためのチェックなどに利用される
#   ため、意図しない書き換えにご注意ください。
#
#   `IMPORT_IMPORTED_LIBS` を参照することで、読み込み済みのライブラリと、それが
#   検索パスのどこから読み込まれたかを確認することができます。
#
#   コード例:
#
#     ```
#     for key in "${!IMPORT_IMPORTED_LIBS[@]}"; do
#       printf '%s: %s\n' "$key" "${IMPORT_IMPORTED_LIBS[${key}]}"
#     done
#     ```
#
# * Import Path *
#
#   デフォルトでは `${DOTFILES_PATH}/lib/bash` から `<library名>.sh` を検索します。
#   検索パスを追加したい場合は `DOTFILES_IMPORT_PATH` を定義します。
#   PATH環境変数と同じ形式(:区切り)の文字列で指定し、左から優先されます。
#   既定のパスは常に末尾に加わるため、上書きではなく追加になります。
#   空の要素は無視します。
#
#   探索のたびに `DOTFILES_IMPORT_PATH` は読み直されるため、import.sh読み込み後に
#   設定してもその時点から反映されます。
#
# * Metadata *
#
#   ライブラリの依存関係と要求bashバージョンは、ファイル先頭のコメントに
#   `@<ディレクティブ> <値>` の形式で記述します。
#
#     ```
#     # shellcheck shell=bash
#
#     # @deps core theme
#     # @requires-bash >=4.1
#     ```
#
#   メタ情報は先頭からコメント行(と空行)を走査することで読み取り、最初のコメント
#   以外の行に達した時点で終了します。
#
#   `@deps` には、そのライブラリが依存するライブラリ名を空白区切りで指定します。
#   `import()` の引数として再帰的に依存ライブラリの解決を行います。
#   省略した場合は依存なしとして扱います。
#
#   `@requires-bash` には、そのライブラリが要求するbashバージョンを
#   `<version specifier><version>` の形式で指定します。
#   使用可能な指定子は `==` 、`!=` 、`>=` 、`<=` 、`>` 、`<` です。
#   省略した場合は `>=0` として判定されます。
#   条件が満たされない場合は、エラーでimportを停止します。
#
#   認識しない `@<ディレクティブ>` は、ただのコメント行として無視します。
#
# * Error Handling *
#
#   importの失敗は、呼び出し元のシェルを終了させます。ライブラリが見つからない、
#   循環依存を検出した、要求bashバージョンを満たさない、といった場合は
#   `exit 1` します。`return` で呼び出し元に失敗を返すことはしません。
#
#   import.sh は source して使うため、この終了は呼び出し元のシェルごと落とすことを
#   意味します。対話シェルで実行した場合はそのシェルが閉じます。
#
#   読み込めるかどうかで処理を分けたい場合は、サブシェルで試してから本読み込み
#   します。
#
#     ```
#     import::available() { ( import "$1" ) >/dev/null 2>&1; }
#
#     if import::available optional_lib; then
#       import optional_lib
#     fi
#     ```
#
# * Debug *
#
#   IMPORT_DEBUG=1 を設定することで、詳細なdebug情報を出力します。

: "${IMPORT_INITIALIZED=0}"
: "${IMPORT_DEBUG:=0}"
: "${DOTFILES_IMPORT_PATH:=}"

import::_depth() {
  local func depth=0
  for func in "${FUNCNAME[@]}"; do
    [[ "$func" == 'import' ]] && (( depth++ ))
  done
  printf '%d\n' "$(( depth - 1 ))"
}

import::_debug() {
  (( IMPORT_DEBUG )) || return 0

  local tab=2
  local spaces=''
  local depth
  depth="$(import::_depth)"
  depth="$(( depth < 0 ? 0 : depth ))"
  (( depth > 0 )) && spaces="$(printf '%*s' "$(( depth * tab ))" '')"
  printf '[IMPORT DEBUG] depth[%02d]: %s%s\n' "$depth" "$spaces" "$*" >&2
}

import::_error() {
  printf '[IMPORT ERROR] %s\n' "$*" >&2
}

import::_abort() {
  import::_error "$@"
  exit 1
}

import::_version_compare() {
  # usage: import::_version_compare "a_version" "b_version"
  # a = b: 0
  # a > b: 1
  # a < b: -1

  local a_version="$1"
  local b_version="$2"
  local a_versions=()
  local b_versions=()

  IFS='.' read -ra a_versions <<< "$a_version"
  IFS='.' read -ra b_versions <<< "$b_version"

  local i
  local max="${#a_versions[@]}"
  (( ${#b_versions[@]} > max )) && max="${#b_versions[@]}"

  # 10# を付けて基数を固定する。付けないと 08 や 09 が8進数として解釈され、
  # "value too great for base" で比較が失敗する。
  for (( i = 0; i < max; i++ )); do
    local a="${a_versions[i]:-0}"
    local b="${b_versions[i]:-0}"

    if (( 10#$a > 10#$b )); then
      printf '%d' 1
      return 0
    fi

    if (( 10#$a < 10#$b )); then
      printf '%d' -1
      return 0
    fi
  done

  printf '%d' 0
  return 0
}

import::_version_satisfies() {
  local requirement="$1"
  local version="${2:-"${BASH_VERSION}"}"
  local op required cmp

  # 演算子は `>` `<` `>=` `<=` `==` `!=` の6種。[><=!]=? だと `=` や `!` 単独も
  # 通ってしまい、要求の書き誤りが "unsupported operator" として報告される。
  if [[ "$requirement" =~ ^([><]=?|[=!]=)([0-9]+(\.[0-9]+)*)$ ]]; then
    op="${BASH_REMATCH[1]}"
    required="${BASH_REMATCH[2]}"
  else
    import::_error "invalid version requirement: ${requirement}"
    return 1
  fi

  if [[ "$version" =~ ^([0-9]+(\.[0-9]+)*).*$ ]]; then
    version="${BASH_REMATCH[1]}"
  else
    import::_error "invalid version: ${version}"
    return 1
  fi

  cmp="$(import::_version_compare "$version" "$required")"
  case "$op" in
    '==') (( cmp == 0 )) ;;
    '!=') (( cmp != 0 )) ;;
    '>')  (( cmp > 0 )) ;;
    '>=') (( cmp >= 0 )) ;;
    '<')  (( cmp < 0 )) ;;
    '<=') (( cmp <= 0 )) ;;
    *)
      import::_error "unsupported operator: ${op}"
      return 1
      ;;
  esac
}

import::_find_library_file() {
  # usage: import::_find_library_file <library名> <検索パス>
  # 検索パスは PATH と同じ :区切りの文字列。見つけたファイルのパスを出力する。
  local lib="$1"
  local p filepath
  local -a paths=()

  IFS=':' read -ra paths <<< "$2"
  for p in "${paths[@]}"; do
    # 空の要素は読み飛ばす。PATHと違い常に "${p}/" を前置するため、空要素は
    # カレントディレクトリではなくルート直下を指してしまう。
    [[ -z "$p" ]] && continue
    filepath="${p}/${lib}.sh"
    [[ -r "$filepath" ]] && { printf '%s\n' "$filepath"; return 0; }
  done
  return 1
}

import::_read_metadata() {
  # ライブラリ先頭のコメントからメタ情報を読み、以下のグローバルにセットする。
  #   _IMPORT_META_DEPS          : @deps を空白で分割した配列
  #   _IMPORT_META_REQUIRES_BASH : @requires-bash の値 (未指定なら空)
  local libfile="$1"
  local line directive value

  _IMPORT_META_DEPS=()
  _IMPORT_META_REQUIRES_BASH=

  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ -z "${line//[[:space:]]/}" ]] && continue
    [[ "$line" =~ ^#.* ]] || break
    [[ "$line" =~ ^#[[:space:]]*@([a-z-]+)[[:space:]]+(.+)$ ]] || continue
    directive="${BASH_REMATCH[1]}"
    value="${BASH_REMATCH[2]}"
    case "$directive" in
      deps) IFS=' ' read -ra _IMPORT_META_DEPS <<< "$value" ;;
      requires-bash) _IMPORT_META_REQUIRES_BASH="${value%%[[:space:]]*}" ;;
      *) ;;
    esac
  done < "$libfile"
}

import::_resolving_stack_contains(){
  local item target="$1"
  for item in "${_IMPORT_RESOLVING_STACK[@]}"; do
    [[ "$item" == "$target" ]] && return 0
  done
  return 1
}

import() {
  local lib libfile requires_bash import_path
  local -a deps

  import::_debug "currently imported libraries: ${!IMPORT_IMPORTED_LIBS[*]}"
  import::_debug "importing libraries: $*"

  for lib in "$@"; do
    import::_debug ">>> importing ${lib}"

    # 読み込み済みチェック
    if [[ -n "${IMPORT_IMPORTED_LIBS[${lib}]:-}" ]]; then
      import::_debug 'already imported.'
      import::_debug '<<< continue'
      continue
    fi

    # 循環検出
    import::_debug "checking if ${lib} is in the resolving stack..."
    if import::_resolving_stack_contains "$lib"; then
      import::_abort \
        "circular library dependency detected: ${_IMPORT_RESOLVING_STACK[*]} -> ${lib}"
    else
      import::_debug "${lib} is not in the resolving stack."
      import::_debug 'pushing to resolving stack...'
      _IMPORT_RESOLVING_STACK+=( "$lib" )
    fi

    import::_debug "resolving stack: ${_IMPORT_RESOLVING_STACK[*]}"

    # モジュール探索
    import::_debug "searching library file ${lib}.sh..."
    import_path="${DOTFILES_IMPORT_PATH:+${DOTFILES_IMPORT_PATH}:}${DOTFILES_PATH}/lib/bash"
    if ! libfile=$(import::_find_library_file "$lib" "$import_path"); then
      import::_abort "library file not found: ${lib} (searched: ${import_path})"
    else
      import::_debug "library file found: ${libfile}"
    fi

    # メタ情報取得
    #   _IMPORT_META_* は再帰するimportで上書きされるため、ローカルへ退避する。
    import::_debug "reading metadata..."
    import::_read_metadata "$libfile"
    deps=( "${_IMPORT_META_DEPS[@]}" )
    requires_bash="${_IMPORT_META_REQUIRES_BASH:->=0}"

    import::_debug "dependent libraries: ${deps[*]:-none}"
    import::_debug "library requires bash version: ${requires_bash}"

    if ! import::_version_satisfies "$requires_bash"; then
      import::_abort "${lib}: bash ${requires_bash} is required (current: ${BASH_VERSION})"
    fi

    # 依存ライブラリ解決
    if (( ${#deps[@]} != 0 )); then
      import::_debug '{{{ resolving dependent libraries...'
      import "${deps[@]}"
      import::_debug '}}} resolved library dependencies.'
    fi

    # ライブラリ読み込み
    import::_debug "loading ${lib}..."
    # shellcheck source=/dev/null
    source "$libfile" || import::_abort "failed to source ${libfile}"
    import::_debug 'removing from resolving stack...'
    unset '_IMPORT_RESOLVING_STACK[${#_IMPORT_RESOLVING_STACK[@]}-1]'
    IMPORT_IMPORTED_LIBS["$lib"]="$libfile"
    import::_debug "<<< imported ${lib}"
  done

  # import::_depth はコマンド置換で fork するため、デバッグ無効時は評価しない。
  if (( IMPORT_DEBUG )) && (( $(import::_depth) == 0 )); then
    import::_debug 'import completed!'
  fi
}

import::_init() {
  # 4.4 未満では `set -u` のもとで空配列の `"${arr[@]}"` 展開が unbound variable に
  # なる。この挙動は 4.4 で修正された。スクリプト側は `set -ueo pipefail` を敷いて
  # いるため、4.3 以下ではライブラリの読み込み自体が失敗する。
  local requires_bash='>=4.4'
  local preload_libs=( core )

  if [ -z "${BASH_VERSION:-}" ]; then
    printf 'import: must be sourced from bash.\n' >&2
    exit 1
  fi

  (( IMPORT_INITIALIZED )) && return 0

  import::_debug "bash version ${BASH_VERSION}"
  import::_debug "initializing..."

  if ! import::_version_satisfies "$requires_bash"; then
    import::_abort "bash ${requires_bash} is required (current: ${BASH_VERSION})"
  fi

  if [[ -z "${DOTFILES_PATH:-}" ]]; then
    import::_abort 'DOTFILES_PATH is not defined.' >&2
  fi

  declare -gA IMPORT_IMPORTED_LIBS=()
  declare -ga _IMPORT_RESOLVING_STACK=()
  declare -ga _IMPORT_META_DEPS=()
  declare -g  _IMPORT_META_REQUIRES_BASH=

  import::_debug "preloading core libraries..."
  import "${preload_libs[@]}"

  IMPORT_INITIALIZED=1
}

import::_init
