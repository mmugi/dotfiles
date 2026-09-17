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
#     # @requires-bash 4.1
#     ```
#
#   メタ情報は先頭からコメント行(と空行)を走査することで読み取り、最初のコメント
#   以外の行に達した時点で終了します。
#
#   `@deps` には、そのライブラリが依存するライブラリ名を空白区切りで指定します。
#   `import()` の引数として再帰的に依存ライブラリの解決を行います。
#   省略した場合は依存なしとして扱います。
#
#   `@requires-bash` には、そのライブラリが要求するbashの最小バージョンを
#   `<major>[.<minor>]` の形式で指定します。省略した場合は `0` として扱われ、
#   条件は常に満たされます。満たされない場合は、エラーでimportを停止します。
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

: "${IMPORT_INITIALIZED=0}"

import::_die() {
  printf '[IMPORT ERROR] %s\n' "$*" >&2
  exit 1
}

import::_version_satisfies() {
  # usage: import::_version_satisfies <最小バージョン> [<比較対象バージョン>]
  # 比較対象を省略すると実行中のbashを見る。<major>[.<minor>] までを比較する。
  local -a required=() current=()

  # 比較は major.minor まで。書き誤りと未実装の桁を黙って通さないよう、形式が
  # 違えば停止する。
  [[ "$1" =~ ^[0-9]+(\.[0-9]+)?$ ]] \
    || import::_die "invalid version requirement: ${1}"

  IFS='.' read -ra required <<< "$1"
  IFS='.' read -ra current <<< "${2:-"${BASH_VERSINFO[0]}.${BASH_VERSINFO[1]}"}"

  # 10# を付けて基数を固定する。付けないと 08 や 09 が8進数として解釈され、
  # "value too great for base" で比較が失敗する。
  local -i req_major="10#${required[0]}" req_minor="10#${required[1]:-0}"
  local -i cur_major="10#${current[0]}"  cur_minor="10#${current[1]:-0}"

  (( cur_major > req_major || (cur_major == req_major && cur_minor >= req_minor) ))
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

import() {
  local lib libfile requires_bash import_path
  local -a deps

  for lib in "$@"; do
    # 読み込み済みチェック
    if [[ -n "${IMPORT_IMPORTED_LIBS[${lib}]:-}" ]]; then
      continue
    fi

    # 循環検出
    #   解決中のスタックは空白区切りの文字列。前後を空白で挟んで部分一致させる
    #   ことで、ライブラリ名の完全一致を見る。
    if [[ " ${_IMPORT_RESOLVING_STACK} " == *" ${lib} "* ]]; then
      import::_die \
        "circular library dependency detected: ${_IMPORT_RESOLVING_STACK# } -> ${lib}"
    fi
    _IMPORT_RESOLVING_STACK+=" ${lib}"

    # モジュール探索
    import_path="${DOTFILES_IMPORT_PATH:+${DOTFILES_IMPORT_PATH}:}${DOTFILES_PATH}/lib/bash"
    if ! libfile=$(import::_find_library_file "$lib" "$import_path"); then
      import::_die "library file not found: ${lib} (searched: ${import_path})"
    fi

    # メタ情報取得
    #   _IMPORT_META_* は再帰するimportで上書きされるため、ローカルへ退避する。
    import::_read_metadata "$libfile"
    deps=( "${_IMPORT_META_DEPS[@]}" )
    requires_bash="${_IMPORT_META_REQUIRES_BASH:-0}"

    if ! import::_version_satisfies "$requires_bash"; then
      import::_die "${lib}: bash ${requires_bash} is required (current: ${BASH_VERSION})"
    fi

    # 依存ライブラリ解決
    if (( ${#deps[@]} != 0 )); then
      import "${deps[@]}"
    fi

    # ライブラリ読み込み
    # shellcheck source=/dev/null
    source "$libfile" || import::_die "failed to source ${libfile}"
    _IMPORT_RESOLVING_STACK="${_IMPORT_RESOLVING_STACK% *}"
    IMPORT_IMPORTED_LIBS["$lib"]="$libfile"
  done
}

import::_init() {
  # 4.4 未満では `set -u` のもとで空配列の `"${arr[@]}"` 展開が unbound variable に
  # なる。この挙動は 4.4 で修正された。スクリプト側は `set -ueo pipefail` を敷いて
  # いるため、4.3 以下ではライブラリの読み込み自体が失敗する。
  local requires_bash='4.4'
  local preload_libs=( core )

  if [ -z "${BASH_VERSION:-}" ]; then
    printf 'import: must be sourced from bash.\n' >&2
    exit 1
  fi

  (( IMPORT_INITIALIZED )) && return 0

  if ! import::_version_satisfies "$requires_bash"; then
    import::_die "bash ${requires_bash} is required (current: ${BASH_VERSION})"
  fi

  if [[ -z "${DOTFILES_PATH:-}" ]]; then
    import::_die 'DOTFILES_PATH is not set'
  fi

  declare -gA IMPORT_IMPORTED_LIBS=()
  declare -g  _IMPORT_RESOLVING_STACK=
  declare -ga _IMPORT_META_DEPS=()
  declare -g  _IMPORT_META_REQUIRES_BASH=

  import "${preload_libs[@]}"

  IMPORT_INITIALIZED=1
}

import::_init
