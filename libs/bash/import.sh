#!/usr/bin/env bash

### Bashモジュールローダー
#
# usage:
#   source path/to/import.sh
#   import <module名>
#
# LIB_PATHから <module名>.sh を探索してsourceします。
# 依存関係は各ライブラリのメタ情報で管理します。
#
# ライブラリ側に必要なメタ情報
# LIB_VERSION='1.0.0'
# LIB_DEPS=''    #空白区切り
# [[ ${1:-} = __META_PROBE__ ]] && return 0

set -Eueo pipefail

: "${DOTFILES_DIR:="$HOME/.dotfiles"}"

# デフォルト検索パス
declare -a LIB_PATH_DEFAULT=(
  "$DOTFILES_DIR/libs/bash"
)

# 左から優先されます。LIB_PATH で優先パスを追加可能です。
# 複数追加する場合、:区切りで与えることも可能です。
if [[ -n ${LIB_PATH:-} ]]; then
  IFS=: read -r -a LIB_PATH_EXTRA <<< "$LIB_PATH"
  LIB_PATH=( "${LIB_PATH_EXTRA[@]}" "${LIB_PATH_DEFAULT[@]}" )
else
  LIB_PATH=( "${LIB_PATH_DEFAULT[@]}" )
fi

# 読み込み済みモジュール集合
declare -Ag __IMPORTED=()

# 循環検出用スタック
declare -ag __RESOLVING_STACK=()

_abort() { printf 'import error: %s\n' "$*" >&2; exit 1; }

_find_module_file() {
  local module="$1" path filepath
  for path in "${LIB_PATH[@]}"; do
    filepath="$path/$module.sh"
    [[ -r $filepath ]] && { printf '%s\n' "$filepath"; return 0; }
  done
  return 1
}

# 循環検出
_in_resolving_stack(){
  local t="$1"
  for s in "${__RESOLVING_STACK[@]}"; do
    [[ $s = "$t" ]] && return 0
  done
  return 1
}

import() {
  local module file
  for module in "$@"; do
    # 読み込み済み
    [[ -n ${__IMPORTED[$module]:-} ]] && continue

    # 循環検出
    if _in_resolving_stack "$module"; then
      _abort "cyclic dependency detected: ${__RESOLVING_STACK[*]} -> $module"
    fi
    __RESOLVING_STACK+=("$module")

    # モジュール探索
    if ! file=$(_find_module_file "$module"); then
      echo "$file"
      _abort "module not found: $module (searched: ${LIB_PATH[*]})"
    fi

    # メタ情報取得
    # ライブラリ側で引数 __META_PROBE__ で分岐
    # __META_PROBE__ の場合メタ情報のみ定義されるようにする
    # shellcheck source=/dev/null
    source "$file" '__META_PROBE__' || _abort "failed to retriving meta: $file"

    local module_version="${LIB_VERSION:-0.0.0}"
    local module_deps="${LIB_DEPS:-}"  # 空白区切り

    # 依存ライブラリを先に読み込む
    if [[ -n $module_deps ]]; then
      # shellcheck disable=SC2206
      local deps_arry=( $module_deps )
      import "${deps_arry[@]}"
    fi

    # ライブラリ読み込み
    # shellcheck source=/dev/null
    source "$file" || _abort "failed to source $file"

    __IMPORTED["$module"]="$module_version"
    unset '__RESOLVING_STACK[${#__RESOLVING_STACK[@]}-1]'
  done
}

module_list(){
  local module
  for module in "${!__IMPORTED[@]}"; do
    printf '%s %s\n' "$module" "${__IMPORTED[$module]}"
  done | sort
}
