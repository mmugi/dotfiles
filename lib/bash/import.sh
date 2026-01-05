# bash library loader / import.sh
# shellcheck shell=bash

# usage:
#   source path/to/import.sh
#   import <library名>...
#
# DOTFILES_LIB_PATHから <library名>.sh を探索してsourceします。
# 依存関係は各ライブラリのメタ情報で管理します。
# デフォルトでは $DOTFILES_PATH/lib/bash から検索します。
#
# ライブラリ側に必要なメタ情報
# ライブラリの先頭に以下を定義する必要があります。
# -----
# # shellcheck disable=SC2034
# {
#   LIB_VERSION='1.0.0'
#   LIB_DEPS=()
#   [[ "${1:-}" = '__META_PROBE__' ]] && return 0
# }
# -----

[[ "${_IMPORT_IMPORTED:-false}" == 'true' ]] && return 0
_IMPORT_IMPORTED=true

if [ -z "${BASH_VERSION:-}" ]; then
  printf "\033[1;31m%s\033[0m\n" 'import.sh: please source this library with bash.'
  exit 1
fi

if (( "${BASH_VERSINFO[0]}" < 4 )); then
  printf 'error: %s: this script requires bash 4 or newer.\n' "${BASH_SOURCE[0]}" >&2
  exit 1
fi

if [[ -z "${DOTFILES_PATH:-}" ]]; then
  printf 'To continue, the environment variables \033[1;32mDOTFILES_PATH\033[m must be defined.\n' >&2
  exit 1
fi

_IMPORT_ENTITY="$(realpath -- "${BASH_SOURCE[0]}")"
if [[ "$_IMPORT_ENTITY" != "${DOTFILES_PATH}/lib/bash/import.sh" ]]; then
  printf \
    "DOTFILES_PATH does not match the sourced import.sh: %s/lib/bash/import.sh\n" \
    "$DOTFILES_PATH" >&2
  exit 1
fi

: "${IMPORT_LOG:=false}"

# ライブラリ検索パス定義
# DOTFILES_LIB_PATH 環境変数を定義することで検索パスを追加できます。
# :区切りで複数与えることも可能で、左から優先されます。
declare -a _import_lib_path_default=( "${DOTFILES_PATH}/lib/bash" )
if [[ -n "${DOTFILES_LIB_PATH:-}" ]]; then
  IFS=: read -r -a _import_lib_path_extra <<< "$DOTFILES_LIB_PATH"
  DOTFILES_LIB_PATH=( "${_import_lib_path_extra[@]}" "${_import_lib_path_default[@]}" )
else
  DOTFILES_LIB_PATH=( "${_import_lib_path_default[@]}" )
fi

if [[ -t 1 ]]; then
  _import_green="$(printf '\033[32m')"
  _import_blue="$(printf '\033[34m')"
  _import_bold="$(printf '\033[1m')"
  _import_reset="$(printf '\033[m')"
else
  _import_green=''
  _import_blue=''
  _import_bold=''
  _import_reset=''
fi

declare -A _IMPORT_LOADED_LIBS=()
declare -a _IMPORT_RESOLVING_STACK=()

import::_abort() { printf 'import error: %s\n' "$*" >&2; exit 1; }

import::_log() {
  local spaces=''
  local depth="$(( ${#FUNCNAME[@]} - 3 ))"
  if [[ "${IMPORT_LOG:-false}" == 'true' ]]; then
    (( depth > 0 )) && spaces="$(printf '%*s' "$(( depth * 2 ))" '')"
    printf '%s%s\n' "$spaces" "$*"
  else
    :
  fi
}

import::_find_library_file() {
  local library="$1" p filepath
  for p in "${DOTFILES_LIB_PATH[@]}"; do
    filepath="${p}/${library}.sh"
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

import::show_loaded_libs() {
  local library
  for library in "${!_IMPORT_LOADED_LIBS[@]}"; do
    printf '%s %s\n' "$library" "${_IMPORT_LOADED_LIBS[$library]}"
  done | sort
}

import() {
  local library libfile library_version library_deps
  local -r bar='----------------'

  import::_log "${_import_bold}${bar} import loop ($*) ${bar}${_import_reset}"
  import::_log \
    "${_import_bold}${_import_blue}*${_import_reset} imported libraries:" \
    "${_import_bold}${_import_blue}${!_IMPORT_LOADED_LIBS[*]}${_import_reset}"

  for library in "$@"; do
    import::_log "${_import_green}>>>${_import_reset} import (${library})"

    # 読み込み済み
    if [[ -n "${_IMPORT_LOADED_LIBS[$library]:-}" ]]; then
      import::_log 'already imported.'
      import::_log "${_import_green}<<<${_import_reset} continue"
      continue
    fi

    # 循環検出
    import::_log "checking if '${library}' is in the resolving stack..."
    if import::_resolving_stack_contains "$library"; then
      import::_abort \
        "cyclic dependency detected: ${_IMPORT_RESOLVING_STACK[*]} -> ${library}"
    else
      import::_log "'${library}' is not in the resolving stack."
      import::_log 'adding resolving stack...'
      _IMPORT_RESOLVING_STACK+=("$library")
    fi

    import::_log "resolving stack: ${_IMPORT_RESOLVING_STACK[*]}"

    # モジュール探索
    import::_log "searching library file '${library}.sh'..."
    if ! libfile=$(import::_find_library_file "$library"); then
      import::_abort "library file not found: ${library} (searched: ${DOTFILES_LIB_PATH[*]})"
    else
      import::_log "library file found: ${libfile}"
    fi

    # ライブラリのメタ情報を取得
    # 各ライブラリは '__META_PROBE__' を引数に指定した場合に、
    # メタ情報を持つ変数がされるようライブラリ冒頭に定義する。
    import::_log "retrieving metadata..."
    # shellcheck source=/dev/null
    if ! source "$libfile" '__META_PROBE__'; then
      import::_abort "failed to retrieve library metadata: ${libfile}"
    else
      # メタ情報
      library_version="${LIB_VERSION:-0.0.0}"
      library_deps=( "${LIB_DEPS[@]+"${LIB_DEPS[@]}"}" )
      import::_log "dependency librarys: ${library_deps[*]:-none}"
    fi

    # 依存ライブラリを先に読み込む
    if (( "${#library_deps[@]}" != 0 )); then
      import::_log 'importing dependency libraries...'
      import "${library_deps[@]}"
    fi

    # ライブラリ読み込み
    # shellcheck source=/dev/null
    source "$libfile" || import::_abort "failed to source ${libfile}"
    unset '_IMPORT_RESOLVING_STACK[${#_IMPORT_RESOLVING_STACK[@]}-1]'
    _IMPORT_LOADED_LIBS["$library"]="$library_version"
    import::_log "sourced library: ${libfile}"
    import::_log "${_import_green}<<<${_import_reset} imported '${libfile}'"
  done
  import::_log "${_import_bold}${bar} import loop end ($*) ${bar}${_import_reset}"
}
