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
#   `import()` で読み込まれたライブラリは `IMPORT_IMPORTED_LIBS` 連想配列にセットされます。
#   キーは `<library名>、バリューはメタデータ(後述)で定義されるライブラリバージョンがセットされます。
#   この連想配列は、ライブラリの再読み込みなどを防ぐためのチェックなどに利用されるため、
#   意図しない書き換えにご注意ください。
#
#   `IMPORT_IMPORTED_LIBS` を参照することで、読み込み済みのライブラリおよびバージョンを
#   確認することができます。
#
#   コード例:
#
#     ```
#     for key in "${!IMPORT_IMPORTED_LIBS[@]}"; do
#       printf '%s: %s\n' "$key" "${IMPORT_IMPORTED_LIBS[${key}]}"
#     done
#
#     ```
# * Import Path *
#
#   デフォルトでは `${DOTFILES_PATH}/lib/bash` から `<library名>.sh` を検索します。
#   検索パスを追加したい場合は `DOTFILES_IMPORT_PATH` を定義します。
#   PATH環境変数と同じ形式(:区切り)で指定し、左から優先されます。
#
# * Metadata *
#
#   ライブラリのバージョン、依存関係は各ライブラリのメタ情報で管理します。
#   import.shで管理するライブラリの先頭には以下を定義してください。
#
#     ```
#     # shellcheck disable=SC2034
#     LIB_VERSION='v0.0.0'
#     LIB_DEPS=()
#     LIB_REQUIRES_BASH='>=0.0.0'
#     [[ "${1:-}" = '__IMPORT__' ]] && return 0
#     ```
#
#   そのライブラリが依存するライブラリ名を `LIB_DEPS` に配列として保持します。
#   `LIB_DEPS` が空でない場合、`import()` の引数として再帰的に依存ライブラリの解決を行います。#
#
#   `LIB_REQUIRES_BASH` には、そのライブラリが要求するbashバージョンを `<version specifier><version>`
#   の形式の文字列で指定します。
#   使用可能な指定子は `==` 、`!=` 、`>=` 、`<=` 、`>` 、`<` です。
#   この変数は定義しないこともできます。その場合は、`>=0` として判定されます。
#   条件が満たされない場合は、エラーでimportを停止します。
#
# * Debug *
#
#   IMPORT_DEBUG 変数に `true` を設定することで、詳細なdebug情報を出力します。

: "${IMPORT_INITIALIZED=false}"
: "${IMPORT_DEBUG:=false}"
: "${DOTFILES_IMPORT_PATH:=}"

import::_depth() {
  local func depth=0
  for func in "${FUNCNAME[@]}"; do
    [[ "$func" == 'import' ]] && (( depth++ ))
  done
  printf '%d\n' "$(( depth - 1 ))"
}

import::_debug() {
  local tab=2
  local spaces=''
  local depth
  [[ "${IMPORT_DEBUG:-false}" == 'true' ]] || return 0
  depth="$(import::_depth)"
  depth="$(( depth < 0 ? 0 : depth ))"
  (( depth > 0 )) && spaces="$(printf '%*s' "$(( depth * tab ))" '')"
  printf '[IMPORT DEBUG] depth[%02d]: %s%s\n' "$depth" "$spaces" "$*" >&2
}

import::_error() {
  printf '[IMPORT ERROR] %b%s%b\n' "$_import_red" "$*" "$_import_reset" >&2
}

import::_abort() {
  import::_error "$@"
  exit 1
}

import::_hl() { printf '%b%s%b' "${_import_bold}${_import_green}" "$*" "$_import_reset"; }
import::_hl_lib() { printf '%b%s%b' "$_import_green" "$*" "$_import_reset"; }
import::_hl_deps() { printf '%b%s%b' "$_import_blue" "$*" "$_import_reset"; }
import::_hl_bold() { printf '%b%s%b' "$_import_bold" "$*" "$_import_reset"; }
import::_hl_keyword() { printf '%b%s%b' "$_import_cyan" "$*" "$_import_reset"; }

import::_version_compere() {
  # usage: import::_version_compere "a_version" "b_version"
  # a = b: 0
  # a > b: 1
  # a > b: -1

  local a_version="$1"
  local b_version="$2"
  local a_versions=()
  local b_versions=()

  IFS='.' read -ra a_versions <<< "$a_version"
  IFS='.' read -ra b_versions <<< "$b_version"

  local i
  local max="${#a_versions[@]}"
  (( ${#b_versions[@]} > max )) && max="${#b_versions[@]}"

   for (( i = 0; i < max; i++ )); do
     local a="${a_versions[i]:-0}"
     local b="${b_versions[i]:-0}"

     if (( a > b )); then
       printf '%d' 1
       return 0
     fi

     if (( a < b )); then
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

  if [[ "$requirement" =~ ^([><=!]=?)([0-9]+(\.[0-9]+)*)$ ]]; then
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

  cmp="$(import::_version_compere "$version" "$required")"
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
  local lib="$1"
  local p filepath
  for p in "${DOTFILES_IMPORT_PATH[@]}"; do
    filepath="${p}/${lib}.sh"
    [[ -r "$filepath" ]] && { printf '%s\n' "$filepath"; return 0; }
  done
  return 1
}

import::_resolving_stack_contains(){
  local item target="$1"
  for item in "${_IMPORT_RESOLVING_STACK[@]}"; do
    [[ "$item" == "$target" ]] && return 0
  done
  return 1
}

import() {
  local lib libfile libver

  import::_debug \
    "currently imported libraries: $(import::_hl_bold "${!IMPORT_IMPORTED_LIBS[@]}")"
  import::_debug "importing libraries: $(import::_hl_bold "$*")"

  for lib in "$@"; do
    import::_debug "$(import::_hl_lib '>>>') importing $(import::_hl_lib "$lib")"

    # 読み込み済みチェック
    if [[ -n "${IMPORT_IMPORTED_LIBS[${lib}]:-}" ]]; then
      import::_debug 'already imported.'
      import::_debug "$(import::_hl_lib '<<<') continue"
      continue
    fi

    # 循環検出
    import::_debug "checking if $(import::_hl_bold "$lib") is in the resolving stack..."
    if import::_resolving_stack_contains "$lib"; then
      import::_abort \
        "circular library dependency detected: ${_IMPORT_RESOLVING_STACK[*]} -> ${lib}"
    else
      import::_debug "$(import::_hl_bold "$lib") is not in the resolving stack."
      import::_debug 'pushing to resolving stack...'
      _IMPORT_RESOLVING_STACK+=( "$lib" )
    fi

    import::_debug "resolving stack: $(import::_hl_bold "${_IMPORT_RESOLVING_STACK[*]}")"

    # モジュール探索
    import::_debug "searching library file $(import::_hl_bold "${lib}.sh")..."
    if ! libfile=$(import::_find_library_file "$lib"); then
      import::_abort "library file not found: ${lib} (searched: ${DOTFILES_IMPORT_PATH[*]})"
    else
      import::_debug "library file found: $(import::_hl_keyword "$libfile")"
    fi

    if ! grep "$_IMPORT_MARKER" "$libfile" >/dev/null 2>&1; then
      import::_abort "library marker not found: ${_IMPORT_MARKER}: ${libfile}"
    fi

    # メタ情報取得
    import::_debug "retrieving metadata..."
    declare LIB_VERSION=
    declare -a LIB_DEPS=()
    declare LIB_REQUIRES_BASH=

    # shellcheck source=/dev/null
    if ! source "$libfile" "$_IMPORT_MARKER"; then
      import::_abort "failed to retrieve library metadata: ${libfile}"
    else
      if [[ -z "${LIB_VERSION:-}" ]]; then
        libver='undefined'
      elif [[ "${LIB_VERSION,,}" =~ ^[0-9]\.[0-9]\.[0-9]$ ]]; then
        libver="$LIB_VERSION"
      else
        import::_error "invalid version format. epected: x.y.z: ${LIB_VERSION}"
        libver='???'
      fi

      import::_debug "library version: $(import::_hl_keyword "$libver")"
      import::_debug "dependent librarys: $(import::_hl_keyword "${LIB_DEPS[*]:-none}")"
      import::_debug "library reqruies bash version: $(import::_hl_keyword "${LIB_REQUIRES_BASH:-*}")"
    fi

    if ! import::_version_satisfies "${LIB_REQUIRES_BASH:=">=0"}"; then
      import::_abort "${lib}: bash ${LIB_REQUIRES_BASH} is required (current: ${BASH_VERSION})"
    fi

    # 依存ライブラリ解決
    if (( "${#LIB_DEPS[@]}" != 0 )); then
      import::_debug "$(import::_hl_deps "{{{") resolving dependent libraries..."
      import "${LIB_DEPS[@]}"
      import::_debug "$(import::_hl_deps "}}}") resolved library dependencies."
    fi

    # ライブラリ読み込み
    import::_debug "loading $(import::_hl_bold "$lib")..."
    # shellcheck source=/dev/null
    source "$libfile" || import::_abort "failed to source ${libfile}"
    import::_debug 'removinging from resolving stack...'
    unset '_IMPORT_RESOLVING_STACK[${#_IMPORT_RESOLVING_STACK[@]}-1]'
    IMPORT_IMPORTED_LIBS["$lib"]="$libver"
    import::_debug "$(import::_hl_lib '<<<') imported $(import::_hl_lib "$lib")"
  done

  if (( $(import::_depth) == 0 )); then
    import::_debug "$(import::_hl 'import completed!')"
  fi
}

import::_init() {
  local requires_bash='>=4.0'
  local preload_libs=( core )

  if [ -z "${BASH_VERSION:-}" ]; then
    printf 'import: must be sourced from bash.\n' >&2
    exit 1
  fi

  [[ "${IMPORT_INITIALIZED:-false}" == 'true' ]] && return 0

  _import_reset=
  _import_bold=
  _import_red=
  _import_green=
  _import_blue=
  _import_cyan=

  if [[ -t 2  && -z "${NO_COLOR:-}" ]]; then
    _import_reset="$(printf '\033[m')"
    _import_bold="$(printf '\033[1m')"
    _import_red="$(printf '\033[31m')"
    _import_green="$(printf '\033[32m')"
    _import_blue="$(printf '\033[34m')"
    _import_cyan="$(printf '\033[36m')"
  fi

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
  declare -gr _IMPORT_MARKER='__IMPORT__'
  declare -ra _IMPORT_PATH_DEFAULT=( "${DOTFILES_PATH}/lib/bash" )

  # path初期化
  local _import_path_extra
  if [[ -n "${DOTFILES_IMPORT_PATH:-}" ]]; then
    IFS=':' read -r -a _import_path_extra <<< "$DOTFILES_IMPORT_PATH"
    DOTFILES_IMPORT_PATH=( "${_import_path_extra[@]}" "${_IMPORT_PATH_DEFAULT[@]}" )
  else
    DOTFILES_IMPORT_PATH=( "${_IMPORT_PATH_DEFAULT[@]}" )
  fi

  import::_debug "preloading core libraries..."
  import "${preload_libs[@]}"

  IMPORT_INITIALIZED=true
}

import::_init
