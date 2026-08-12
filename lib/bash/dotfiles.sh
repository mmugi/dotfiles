# shellcheck shell=bash

# import.sh がsource時に読み取る変数
# shellcheck disable=SC2034
{
  LIB_VERSION='1.0.0'
  LIB_DEPS=( core )
}
[[ "${1:-}" = '__IMPORT__' ]] && return 0

# shellcheck disable=SC2034
{
  # shellcheck disable=SC2155
  declare -gr DOTFILES_LOGO="$(cat <<LOGO
 _____  _______ _______ _______ _______ _____   _______ _______
|     \|       |_     _|    ___|_     _|     |_|    ___|     __|
|  --  |   -   | |   | |    ___|_|   |_|       |    ___|__     |
|_____/|_______| |___| |___|   |_______|_______|_______|_______|
LOGO
  )"

  # shellcheck disable=SC2155
  declare -gr DOTFILES_LOGO_UNINSTALL="$(cat <<LOGO
 _______ _______ _______ _______ _______ _______ _______ _____   _____
|   |   |    |  |_     _|    |  |     __|_     _|   _   |     |_|     |_
|   |   |       |_|   |_|       |__     | |   | |       |       |       |
|_______|__|____|_______|__|____|_______| |___| |___|___|_______|_______|

LOGO
  )"

  declare -g DOTFILES_CONFIG_DIR="${DOTFILES_PATH:?}/configs"
  declare -g DOTFILES_RUNTIME_DIR="${DOTFILES_PATH:?}/run"
  declare -g DOTFILES_GITHOOKS_DIR="${DOTFILES_PATH:?}/misc/git/hooks/dotfiles"
  declare -g DOTFILES_BREWFILE_DIR="${DOTFILES_PATH:?}/misc/brew"
  declare -g DOTFILES_IGNOREFILE="${DOTFILES_PATH:?}/.dotignore"
}

dotfiles::is_ignored() {
  # usage: dotfiles::is_ignored <config_relpath_from_home>
  #
  # 引数のパスが DOTFILES_IGNOREFILE (.dotignore) で除外されているかを判定する。
  # 引数はホームディレクトリからの相対パスで指定する。
  #
  # .dotignore の各行は行頭にアンカーした正規表現として評価される。
  # 空行と # から始まる行は無視する。
  #
  # install と uninstall の両方から参照するため、ここに置いている。
  # 除外されたパスは dotfiles の管理外として、配置も解除も行わない。

  if (( $# != 1 )); then
    core::error 'usage: dotfiles::is_ignored <config_relpath_from_home>'
    return 1
  fi

  local relpath="$1"
  local pattern

  [[ -s "$DOTFILES_IGNOREFILE" ]] || return 1

  while read -r pattern; do
    [[ -z "$pattern" || "$pattern" =~ ^# ]] && continue
    [[ "$relpath" =~ ^$pattern ]] && return 0
  done < "$DOTFILES_IGNOREFILE"

  return 1
}
